{{/* Resource name: fullnameOverride, else <release>-<chart> (avoids collisions
     between the ConfigMap-app subcharts, which previously used bare
     .Release.Name for every resource). */}}
{{- define "glmocr-pipeline.fullname" -}}
{{- .Values.fullnameOverride | default (printf "%s-%s" .Release.Name .Chart.Name) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Effective OCR backend settings: chart env wins; when GLMOCR_OCR_API_HOST is
     empty, derive host/port/scheme from global.modelEndpoint. */}}
{{- define "glmocr-pipeline.backendEnv" -}}
{{- $env := .Values.env }}
{{- $g := .Values.global | default dict }}
{{- $host := $env.GLMOCR_OCR_API_HOST }}
{{- $port := $env.GLMOCR_OCR_API_PORT }}
{{- $scheme := $env.GLMOCR_OCR_API_SCHEME }}
{{- if and (not $host) $g.modelEndpoint }}
{{- $u := urlParse $g.modelEndpoint }}
{{- $scheme = $u.scheme | default "http" }}
{{- $hostport := $u.host | default "" }}
{{- $parts := splitList ":" $hostport }}
{{- $host = first $parts }}
{{- if gt (len $parts) 1 }}{{- $port = last $parts }}{{- else }}{{- $port = ternary "443" "80" (eq $scheme "https") }}{{- end }}
{{- end }}
- name: GLMOCR_OCR_API_HOST
  value: {{ $host | default "glm-ocr-backend.example.com" | quote }}
- name: GLMOCR_OCR_API_PORT
  value: {{ $port | quote }}
- name: GLMOCR_OCR_API_SCHEME
  value: {{ $scheme | quote }}
{{- end -}}
