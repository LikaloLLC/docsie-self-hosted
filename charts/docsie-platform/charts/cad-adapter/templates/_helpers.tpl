{{/* Resource name: fullnameOverride, else <release>-<chart> (avoids collisions
     between the ConfigMap-app subcharts, which previously used bare
     .Release.Name for every resource). */}}
{{- define "cad-adapter.fullname" -}}
{{- .Values.fullnameOverride | default (printf "%s-%s" .Release.Name .Chart.Name) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Download allowlist: chart value wins; empty = in-cluster MinIO plus the
     public hostname of this install. */}}
{{- define "cad-adapter.allowedHosts" -}}
{{- if .Values.env.CAD_ADAPTER_ALLOWED_HOSTS -}}
{{- .Values.env.CAD_ADAPTER_ALLOWED_HOSTS -}}
{{- else -}}
{{- $g := .Values.global | default dict -}}
{{- printf "minio,%s" ($g.hostname | default "docsie.example.com") -}}
{{- end -}}
{{- end -}}
