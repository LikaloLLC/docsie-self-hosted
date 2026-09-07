# Optional local text-to-speech with Chatterbox

Install Chatterbox when you want local narration or the speech-output component
of a voice agent. It is disabled by default and does not increase the basic Docsie
installation's model memory requirements unless selected.

Dokuta already supports `provider: chatterbox` through an OpenAI-compatible
`/v1/audio/speech` endpoint. This distribution adds an optional model-server chart,
persistent model cache, Dokuta configuration and a WAV-generation test.

## Select the host

| Host | Installation |
| --- | --- |
| Linux AMD64 CPU | `examples/chatterbox-cpu.yaml`; no GPU required, latency depends on CPU |
| Linux AMD64 NVIDIA GPU | `examples/chatterbox-nvidia.yaml`; requires drivers, NVIDIA container runtime and Kubernetes device plugin |
| Apple Silicon | Native CPU server below, then `examples/chatterbox-external.yaml` |
| Existing compatible TTS server | `examples/chatterbox-external.yaml`; no local model server is deployed |

The pinned upstream CPU and NVIDIA images are AMD64. They are not native ARM64
CPU images, and Docker Desktop cannot give a Linux container access to Apple
Metal. The chart selects AMD64 nodes instead of silently relying on emulation.

CPU defaults request one core/4 GiB RAM and limit four cores/8 GiB, with a 20-GiB
persistent model cache. NVIDIA defaults additionally request one GPU. These are
starting allocations, not measured minima, VRAM guarantees or latency benchmarks.
They are additional to Docsie, Ollama and transcription capacity.

## Add to Docsie

Merge the selected example into your private installation values, then run:

```bash
DOCSIE_INSTALL_TIMEOUT=40m bash scripts/install-kubernetes.sh \
  /absolute/path/to/kubeconfig docsie /absolute/path/to/values.yaml
```

The installer waits for the model to load and runs the speech test when the local
Chatterbox deployment is present. To run that test again:

```bash
helm test docsie --filter name=docsie-chatterbox-test \
  --kubeconfig /absolute/path/to/kubeconfig --namespace docsie --logs --timeout 11m
```

The test generates a short WAV and verifies duration and non-silent PCM output.
Listen to a saved sample before accepting a particular voice or model for users.

When Dokuta is installed (currently through `profiles.full`), opting into bundled
or external Chatterbox configures its API/UI/worker endpoint, model and voice.
It enables the generated Dokuta voice API setting; explicit custom Secret settings
can override it. Existing operator-managed Secrets must enable
`DOKUTA_ENABLE_VOICE_API` themselves. Model routing alone does not deploy Dokuta.

Use `voice: Emily.wav` for the supplied example. This server expects a voice
filename; OpenAI voice names such as `alloy` and a generic `default` do not resolve
to its built-in voice files. The model is selected in server configuration, so
changing only a request's `model` field does not switch the loaded model.

## Install just the speech server

For an existing Kubernetes cluster, independently of the rest of Docsie:

```bash
helm upgrade --install speech charts/docsie-platform/charts/chatterbox-tts \
  --kubeconfig /absolute/path/to/kubeconfig --namespace docsie --create-namespace \
  --values examples/chatterbox-cpu.yaml --wait --timeout 40m
helm test speech --filter name=speech-chatterbox-test \
  --kubeconfig /absolute/path/to/kubeconfig --namespace docsie --logs --timeout 11m
```

The generated Service is `http://chatterbox-tts:8004`. Its NetworkPolicy permits
only callers in the same namespace and requires a policy-capable CNI. Keep the
upstream server private: it includes management endpoints and does not enforce
Dokuta's Bearer API key. No public ingress or LoadBalancer is created. Expose the
application's authenticated voice API to users instead.

## Apple Silicon / native model host

Install Python 3.10, Git and FFmpeg first. Then select a new directory:

```bash
bash scripts/install-chatterbox-native.sh /absolute/path/to/chatterbox cpu 8004
```

This installs the pinned upstream source and model-library fork in an isolated
virtual environment, downloads weights on first run, and serves on loopback.
It stays in the foreground; Ctrl-C stops it. For a later start:

```bash
cd /absolute/path/to/chatterbox
PYTORCH_ENABLE_MPS_FALLBACK=1 HF_HOME="$PWD/hf_cache" .venv/bin/python -m uvicorn server:app --host 127.0.0.1 --port 8004
```

CPU is the default. `mps` is experimental: our Turbo test failed in torchaudio
resampling with an unsupported Metal operation, even with CPU fallback enabled.
A Kubernetes caller needs a
reachable model-host endpoint: for Docker Desktop this may be
`http://host.docker.internal:8004`. Test reachability from the calling pod.
For other hosts, configure a private authenticated reverse proxy or private
network binding; loopback is not remotely reachable. `apiKeySecretName` in the
external example is for a proxy/server that actually validates Bearer tokens.

## Model files and offline use

The container includes server dependencies and sample voices. On first startup it
downloads the selected Chatterbox weights from Hugging Face into the PVC. Allow
that download before expecting readiness; an HTTP listener alone is not readiness.
An optional Hugging Face token can come from `huggingFaceTokenSecret`, key `token`.
No token is embedded in the chart.

For offline use, populate the model cache using the same pinned image and model,
copy the full cache to the target PVC, then set `chatterbox-tts.offline: true`.
An empty cache with offline mode fails readiness. This release does not include
an offline model archive or claim the cache is sufficient for every model variant.
Back up the PVC and any custom/reference voices separately; supplied voices remain
in the immutable image. The default chart does not provide persistent custom-voice
uploads or a public administration UI.

## Speech through Dokuta

Against your authenticated Dokuta endpoint, send this body to `/api/v1/voice/speech`:

```json
{"provider":"chatterbox","text":"Docsie can speak locally.","voice":"Emily.wav","response_format":"wav","model":"chatterbox-turbo"}
```

Use the existing API-key/Bearer authentication flow and save the response bytes to
a WAV file. Generation must finish within Dokuta's current 120-second upstream
request timeout; a successful slow standalone CPU test does not establish that.
The current upstream server supports WAV, MP3 and Opus; do not assume every audio
format accepted by Dokuta is supported by this backend.

Live voice calls additionally need LiveKit, the agent worker, transcription,
model routing, media networking and interruption handling. This optional install
provides TTS; it does not qualify the complete live voice-agent workflow.

## Sources and licenses

Images are pinned to immutable manifests from
[devnen/Chatterbox-TTS-Server](https://github.com/devnen/Chatterbox-TTS-Server/tree/915ae289340e10c6047f27f47e22eae9bf350c32).
Its source and the underlying [Resemble AI Chatterbox](https://github.com/resemble-ai/chatterbox)
carry their upstream MIT licenses. Docsie remains proprietary. Keep upstream
notices with any copies and use custom voice samples you are entitled to use.
The CPU/MPS runtime and NVIDIA GPU runtime are separate validation targets.

## Validation for this preview

On 2026-09-07, the pinned server and model-library source on native Apple Silicon
CPU generated a non-silent 1.68-second, 24-kHz WAV using Chatterbox Turbo and
Emily.wav. The same WAV checker ships as a Helm test. This was a model-server
API test, not a Dokuta HTTP API or live-call acceptance test.

Chart rendering, opt-in behavior, external-server routing, Dokuta configuration,
image manifest availability and packaging passed. Linux container execution and
NVIDIA GPU inference remain unverified. Native MPS failed as described above.
