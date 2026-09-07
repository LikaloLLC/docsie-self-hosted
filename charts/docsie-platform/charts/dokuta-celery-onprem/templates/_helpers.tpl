{{/*
Expand the name of the chart.
*/}}
{{- define "celery.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "celery.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "celery.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "celery.labels" -}}
helm.sh/chart: {{ include "celery.chart" . }}
{{ include "celery.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "celery.selectorLabels" -}}
app.kubernetes.io/name: {{ include "celery.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "celery.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "celery.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Project optional LLM gateway runtime keys from the configured secret.
By default this uses the same secret as OPENAI_API_KEY when present, so
staging/prod values with explicit env maps do not need to duplicate LLM_* keys.
*/}}
{{- define "celery.llmEnv" -}}
{{- $env := .Values.env | default dict -}}
{{- $llmEnv := .Values.llmEnv | default dict -}}
{{- $llmEnabled := true -}}
{{- if hasKey $llmEnv "enabled" }}{{- $llmEnabled = get $llmEnv "enabled" }}{{- end -}}
{{- if $llmEnabled -}}
{{- $defaultSecretName := "dokuta-secret" -}}
{{- if hasKey $env "OPENAI_API_KEY" -}}
{{- $openaiEnv := index $env "OPENAI_API_KEY" -}}
{{- if hasKey $openaiEnv "secretName" }}{{- $defaultSecretName = get $openaiEnv "secretName" }}{{- end -}}
{{- end -}}
{{- $llmSecretName := get $llmEnv "secretName" | default $defaultSecretName -}}
{{- $llmOptional := true -}}
{{- if hasKey $llmEnv "optional" }}{{- $llmOptional = get $llmEnv "optional" }}{{- end -}}
{{- $defaultKeys := list "LLM_PROVIDER" "LLM_BASE_URL" "LLM_API_KEY" "LLM_CHAT_MODEL" "LLM_FAST_MODEL" "LLM_VISION_MODEL" "LLM_JSON_MODEL" "LLM_EMBEDDING_MODEL" "LLM_TRANSCRIPTION_MODEL" "LLM_TRANSCRIPTION_PROVIDER" "LLM_TRANSCRIPTION_BASE_URL" "LLM_TRANSCRIPTION_API_KEY" "LLM_BEDROCK_REGION" "AWS_REGION" "AWS_DEFAULT_REGION" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_SESSION_TOKEN" "AWS_BEARER_TOKEN_BEDROCK" "BEDROCK_API_KEY" "GEMINI_API_KEY" "GOOGLE_GEMINI_API_KEY" "GOOGLE_API_KEY" "OLLAMA_API_KEY" "LLM_TIMEOUT_SECONDS" "LLM_MAX_RETRIES" "DOKUTA_COST_LOGGING" "DOKUTA_COST_LEDGER_PATH" "DOKUTA_COST_OPENAI_INPUT_PER_MTOK" "DOKUTA_COST_OPENAI_OUTPUT_PER_MTOK" "DOKUTA_COST_OPENAI_CACHED_INPUT_PER_MTOK" "DOKUTA_COST_OPENAI_WHISPER_1_PER_MINUTE" "DOKUTA_COST_LITELLM_INPUT_PER_MTOK" "DOKUTA_COST_LITELLM_OUTPUT_PER_MTOK" "DOKUTA_COST_LITELLM_CACHED_INPUT_PER_MTOK" "DOKUTA_COST_LITELLM_TRANSCRIPTION_PER_MINUTE" "DOKUTA_COST_GROQ_TRANSCRIPTION_PER_MINUTE" "DOKUTA_COST_OLLAMA_CLOUD_INPUT_PER_MTOK" "DOKUTA_COST_OLLAMA_CLOUD_OUTPUT_PER_MTOK" "DOKUTA_COST_OLLAMA_CLOUD_CACHED_INPUT_PER_MTOK" "DOKUTA_COST_OLLAMA_CLOUD_TRANSCRIPTION_PER_MINUTE" "DOKUTA_COST_BEDROCK_INPUT_PER_MTOK" "DOKUTA_COST_BEDROCK_OUTPUT_PER_MTOK" "DOKUTA_COST_BEDROCK_CACHED_INPUT_PER_MTOK" "DOKUTA_COST_BEDROCK_TRANSCRIPTION_PER_MINUTE" -}}
{{- $llmEnvKeys := $defaultKeys -}}
{{- if hasKey $llmEnv "keys" }}{{- $llmEnvKeys = get $llmEnv "keys" }}{{- end -}}
{{- range $key := $llmEnvKeys }}
{{- if not (hasKey $env $key) }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef:
      name: {{ $llmSecretName }}
      key: {{ $key }}
      optional: {{ $llmOptional }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end }}

{{- define "celery.chatterboxEnv" -}}
{{- $tts := (.Values.global | default dict).chatterbox | default dict }}
{{- if or $tts.enabled $tts.externalUrl }}
{{- $env := .Values.env | default dict }}
{{- $endpoint := $tts.externalUrl | default "http://chatterbox-tts:8004" }}
{{- $values := dict "CHATTERBOX_TTS_BASE_URL" $endpoint "CHATTERBOX_TTS_MODEL" $tts.model "CHATTERBOX_TTS_VOICE" $tts.voice "CHATTERBOX_TTS_ENDPOINT_PATH" "/v1/audio/speech" "DOKUTA_ENABLE_VOICE_API" "true" "CHATTERBOX_VOICE_OPTIONS_JSON" (list (dict "id" $tts.voice "name" "Local Chatterbox voice") | toJson) }}
{{- range $key, $value := $values }}
{{- if not (hasKey $env $key) }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- if and $tts.apiKeySecretName (not (hasKey $env "CHATTERBOX_TTS_API_KEY")) }}
- name: CHATTERBOX_TTS_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $tts.apiKeySecretName }}
      key: {{ $tts.apiKeySecretKey | default "api-key" }}
{{- end }}
{{- end }}
{{- end }}
