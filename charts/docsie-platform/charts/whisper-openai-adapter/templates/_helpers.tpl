{{/* Resource name: fullnameOverride, else <release>-<chart> (avoids collisions
     between the ConfigMap-app subcharts, which previously used bare
     .Release.Name for every resource). */}}
{{- define "whisper-openai-adapter.fullname" -}}
{{- .Values.fullnameOverride | default (printf "%s-%s" .Release.Name .Chart.Name) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
