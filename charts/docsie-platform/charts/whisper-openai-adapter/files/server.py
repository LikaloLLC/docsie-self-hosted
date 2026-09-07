import logging
import os
import time
from typing import Optional

import httpx
import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse, Response


LOG_LEVEL = os.environ.get("WHISPER_ADAPTER_LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO))
logger = logging.getLogger("whisper-openai-adapter")

APP_VERSION = os.environ.get("WHISPER_ADAPTER_VERSION", "0.1.0")
GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "").strip()
GROQ_BASE_URL = os.environ.get("GROQ_BASE_URL", "https://api.groq.com/openai/v1").rstrip("/")
ADAPTER_API_TOKEN = os.environ.get("ADAPTER_API_TOKEN", "").strip()
DEFAULT_MODEL = os.environ.get("WHISPER_MODEL", "whisper-large-v3-turbo").strip()
REQUEST_TIMEOUT = float(os.environ.get("WHISPER_ADAPTER_REQUEST_TIMEOUT", "120"))
MAX_UPLOAD_MB = int(os.environ.get("WHISPER_ADAPTER_MAX_UPLOAD_MB", "100"))
MAX_UPLOAD_BYTES = MAX_UPLOAD_MB * 1024 * 1024

MODEL_ALIASES = {
    "whisper-1": DEFAULT_MODEL,
    "large-v3-turbo": "whisper-large-v3-turbo",
    "large-v3": "whisper-large-v3",
    "faster-whisper-large-v3": "whisper-large-v3",
}

app = FastAPI(title="Docsie Whisper OpenAI Adapter", version=APP_VERSION)


def require_ready() -> None:
    if not GROQ_API_KEY:
        raise HTTPException(status_code=503, detail="GROQ_API_KEY is not configured")


def authorize(request: Request) -> None:
    if not ADAPTER_API_TOKEN:
        return
    expected = f"Bearer {ADAPTER_API_TOKEN}"
    if request.headers.get("Authorization", "") != expected:
        raise HTTPException(status_code=401, detail="Invalid transcription adapter token")


def normalize_model(model: Optional[str]) -> str:
    value = (model or DEFAULT_MODEL or "whisper-large-v3-turbo").strip()
    return MODEL_ALIASES.get(value, value)


async def build_forward_files(file: Optional[UploadFile]):
    if file is None:
        return None

    payload = await file.read()
    if len(payload) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail=f"Audio file exceeds {MAX_UPLOAD_MB} MB limit")

    filename = file.filename or "audio.wav"
    content_type = file.content_type or "application/octet-stream"
    return {"file": (filename, payload, content_type)}


def add_form(data: dict, key: str, value: Optional[object]) -> None:
    if value is None:
        return
    text = str(value)
    if text:
        data[key] = text


async def forward_audio_request(
    *,
    endpoint: str,
    request: Request,
    file: Optional[UploadFile],
    model: Optional[str],
    response_format: Optional[str],
    language: Optional[str],
    prompt: Optional[str],
    temperature: Optional[float],
    timestamp_granularities: Optional[str],
    url: Optional[str],
) -> Response:
    require_ready()
    authorize(request)

    files = await build_forward_files(file)
    data = {}
    add_form(data, "model", normalize_model(model))
    add_form(data, "response_format", response_format)
    add_form(data, "language", language)
    add_form(data, "prompt", prompt)
    add_form(data, "temperature", temperature)
    add_form(data, "timestamp_granularities[]", timestamp_granularities)
    add_form(data, "url", url)

    if files is None and not url:
        raise HTTPException(status_code=400, detail="Provide either an audio file or url")

    headers = {
        "Authorization": f"Bearer {GROQ_API_KEY}",
        "User-Agent": f"DocsieWhisperOpenAIAdapter/{APP_VERSION}",
    }

    started = time.time()
    target = f"{GROQ_BASE_URL}/audio/{endpoint}"
    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            upstream = await client.post(target, data=data, files=files, headers=headers)
    except httpx.TimeoutException as exc:
        raise HTTPException(status_code=504, detail="Groq transcription request timed out") from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Groq transcription request failed: {exc}") from exc

    elapsed_ms = int((time.time() - started) * 1000)
    logger.info(
        "Groq %s completed status=%s model=%s elapsed_ms=%s",
        endpoint,
        upstream.status_code,
        data.get("model"),
        elapsed_ms,
    )

    content_type = upstream.headers.get("content-type", "application/json")
    if upstream.status_code >= 400:
        return Response(content=upstream.content, status_code=upstream.status_code, media_type=content_type)
    return Response(content=upstream.content, status_code=upstream.status_code, media_type=content_type)


@app.get("/health")
async def health():
    if not GROQ_API_KEY:
        return JSONResponse({"status": "unconfigured", "groq_api_key": False}, status_code=503)
    return {
        "status": "ok",
        "provider": "groq",
        "default_model": DEFAULT_MODEL,
        "supported_models": ["whisper-large-v3-turbo", "whisper-large-v3"],
    }


@app.get("/v1/models")
async def models(request: Request):
    authorize(request)
    return {
        "object": "list",
        "data": [
            {"id": "whisper-large-v3-turbo", "object": "model", "owned_by": "groq"},
            {"id": "whisper-large-v3", "object": "model", "owned_by": "groq"},
        ],
    }


@app.post("/v1/audio/transcriptions")
async def transcriptions(
    request: Request,
    file: Optional[UploadFile] = File(default=None),
    model: Optional[str] = Form(default=None),
    response_format: Optional[str] = Form(default="json"),
    language: Optional[str] = Form(default=None),
    prompt: Optional[str] = Form(default=None),
    temperature: Optional[float] = Form(default=None),
    timestamp_granularities: Optional[str] = Form(default=None),
    max_speech_duration_s: Optional[str] = Form(default=None),
    min_silence_duration_ms: Optional[str] = Form(default=None),
    url: Optional[str] = Form(default=None),
):
    # Vexa may send VAD tuning fields. Groq does not accept them, so we ignore
    # them here while preserving OpenAI-compatible behavior for the client.
    _ = (max_speech_duration_s, min_silence_duration_ms)
    return await forward_audio_request(
        endpoint="transcriptions",
        request=request,
        file=file,
        model=model,
        response_format=response_format,
        language=language,
        prompt=prompt,
        temperature=temperature,
        timestamp_granularities=timestamp_granularities,
        url=url,
    )


@app.post("/v1/audio/translations")
async def translations(
    request: Request,
    file: Optional[UploadFile] = File(default=None),
    model: Optional[str] = Form(default=None),
    response_format: Optional[str] = Form(default="json"),
    prompt: Optional[str] = Form(default=None),
    temperature: Optional[float] = Form(default=None),
    url: Optional[str] = Form(default=None),
):
    return await forward_audio_request(
        endpoint="translations",
        request=request,
        file=file,
        model=model,
        response_format=response_format,
        language=None,
        prompt=prompt,
        temperature=temperature,
        timestamp_granularities=None,
        url=url,
    )


if __name__ == "__main__":
    host = os.environ.get("WHISPER_ADAPTER_HOST", "0.0.0.0")
    port = int(os.environ.get("WHISPER_ADAPTER_PORT", "8080"))
    uvicorn.run(app, host=host, port=port)
