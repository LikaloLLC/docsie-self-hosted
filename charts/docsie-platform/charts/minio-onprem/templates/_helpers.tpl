{{/* Secret name holding the MinIO root credentials */}}
{{- define "minio.authSecretName" -}}
{{- .Values.auth.existingSecret | default .Values.auth.secretName -}}
{{- end -}}

{{/* Optional global image registry prefix, e.g. "registry.local:5000/" */}}
{{- define "minio.imagePrefix" -}}
{{- $g := .Values.global | default dict -}}
{{- with $g.imageRegistry }}{{ . }}/{{ end -}}
{{- end -}}

{{/* Effective storage class: chart value, then global.storageClass */}}
{{- define "minio.storageClass" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.persistence.storageClassName | default ($g.storageClass | default "") -}}
{{- end -}}
