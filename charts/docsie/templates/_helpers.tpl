{{/*
Resolve the secret name based on provider
*/}}
{{- define "docsie.secretName" -}}
{{- if eq .Values.global.secretProvider "doppler" -}}
{{ .Values.doppler.managedSecretName }}
{{- else -}}
{{ .Values.manualSecret.name }}
{{- end -}}
{{- end -}}

{{/*
Resolve the ServiceAccount name
*/}}
{{- define "docsie.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default "docsie" .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Optional config mounts shared by all Docsie workloads.
*/}}
{{- define "docsie.configVolumeMounts" -}}
{{- $search := .Values.global.appSearch | default dict }}
{{- if or $search.enabled .Values.mongo.caSecretName .Values.onpremSettings.configMapName .Values.workload.extraVolumeMounts }}
volumeMounts:
{{- if $search.enabled }}
  - name: appsearch-ca
    mountPath: /etc/docsie/appsearch-ca
    readOnly: true
{{- end }}
{{- if .Values.mongo.caSecretName }}
  - name: mongo-ca
    mountPath: {{ .Values.mongo.caMountPath }}
    readOnly: true
{{- end }}
{{- if .Values.onpremSettings.configMapName }}
  - name: onprem-settings
    mountPath: /app/config/settings/onprem.py
    subPath: {{ default "onprem.py" .Values.onpremSettings.fileName }}
    readOnly: true
{{- if .Values.onpremSettings.baseKey }}
  - name: onprem-settings
    mountPath: /app/config/settings/base.py
    subPath: {{ default "base.py" .Values.onpremSettings.baseFileName }}
    readOnly: true
{{- end }}
{{- end }}
{{- with .Values.workload.extraVolumeMounts }}
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "docsie.configVolumes" -}}
{{- $search := .Values.global.appSearch | default dict }}
{{- if or $search.enabled .Values.mongo.caSecretName .Values.onpremSettings.configMapName .Values.workload.extraVolumes }}
volumes:
{{- if $search.enabled }}
  - name: appsearch-ca
    secret:
      secretName: {{ $search.caSecretName | quote }}
{{- end }}
{{- if .Values.mongo.caSecretName }}
  - name: mongo-ca
    secret:
      secretName: {{ .Values.mongo.caSecretName }}
      items:
        - key: {{ .Values.mongo.caFileKey }}
          path: {{ .Values.mongo.caFileName }}
{{- end }}
{{- if .Values.onpremSettings.configMapName }}
  - name: onprem-settings
    configMap:
      name: {{ .Values.onpremSettings.configMapName }}
      items:
        - key: {{ default "onprem.py" .Values.onpremSettings.key }}
          path: {{ default "onprem.py" .Values.onpremSettings.fileName }}
{{- if .Values.onpremSettings.baseKey }}
        - key: {{ .Values.onpremSettings.baseKey }}
          path: {{ default "base.py" .Values.onpremSettings.baseFileName }}
{{- end }}
{{- end }}
{{- with .Values.workload.extraVolumes }}
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Whether the lookup-guarded generated secret is active (manual provider only).
Returns "true" or empty string.
*/}}
{{- define "docsie.generatedSecretEnabled" -}}
{{- if and (eq .Values.global.secretProvider "manual") .Values.manualSecret.generate .Values.manualSecret.generate.enabled -}}true{{- end -}}
{{- end -}}

{{/*
Name of the generated secret.
*/}}
{{- define "docsie.generatedSecretName" -}}
{{ default "docsie-generated-secret" .Values.manualSecret.generate.name }}
{{- end -}}

{{/*
Name of the optional static CDN proxy workload/service.
*/}}
{{- define "docsie.staticProxyName" -}}
docsie-static
{{- end -}}

{{/*
Env entries for a docsie app container: chart-wide plainEnv (non-secret map)
and env (secretKeyRef map) merged with per-component overrides, plus
workload.extraEnv and per-component extraEnv lists. Renders nothing when all
are empty. Call with (dict "root" $ "component" <componentValues>).
*/}}
{{- define "docsie.workloadEnv" -}}
{{- $root := .root -}}
{{- $component := default (dict) .component -}}
{{- $plainEnv := merge (deepCopy (default (dict) $component.plainEnv)) (default (dict) $root.Values.plainEnv) -}}
{{- if $root.Values.global.selfHosted }}
{{- $hostname := required "global.hostname is required" $root.Values.global.hostname }}
{{- $base := printf "%s://%s" $root.Values.global.scheme $hostname }}
{{- $defaults := dict "DJANGO_SETTINGS_MODULE" "config.settings.onprem" "ENTERPRISE_MODE" "true" "DOMAIN" $hostname "APP_BASE_URL" $base "BASE_URL" $base "DOCSIE_BASE_URL" $base "CSRF_TRUSTED_ORIGINS" $base "ADDITIONAL_ALLOWED_HOSTS" (printf "%s,docsie-web,localhost,127.0.0.1" $hostname) }}
{{- if $root.Values.global.modelEndpoint }}
{{- $_ := set $defaults "OPENAI_API_BASE" $root.Values.global.modelEndpoint }}
{{- $_ := set $defaults "OLLAMA_API_BASE" $root.Values.global.modelEndpoint }}
{{- end }}
{{- $plainEnv = merge $plainEnv $defaults }}
{{- end }}
{{- $secretEnv := merge (deepCopy (default (dict) $component.env)) (default (dict) $root.Values.env) -}}
{{- $search := $root.Values.global.appSearch | default dict }}
{{- if $search.enabled }}
{{- $publicHost := $search.publicHost | default (printf "search.%s/api/as/v1" $root.Values.global.hostname) }}
{{- $plainEnv = merge $plainEnv (dict
  "APPSEARCH_HOST" (printf "%s:3002/api/as/v1" $search.serviceName)
  "APPSEARCH_SEARCH_HOST" $publicHost
  "APPSEARCH_USE_HTTPS" "true"
  "APPSEARCH_VERIFY_CERTS" "true"
  "APPSEARCH_CA_CERT_PATH" "/etc/docsie/appsearch-ca/tls.crt"
  "APPSEARCH_SEARCH_KEY_NAME" "docsie-search-signing") }}
{{- range $key := list "APPSEARCH_KEY" "APPSEARCH_SEARCH_KEY" }}
{{- $_ := set $secretEnv $key (dict "secretName" (printf "%s-appsearch-runtime" $root.Release.Name) "key" $key) }}
{{- end }}
{{- end }}
{{- $extraEnv := concat (default (list) $root.Values.workload.extraEnv) (default (list) $component.extraEnv) -}}
{{- if or $plainEnv $secretEnv $extraEnv -}}
env:
{{- range $key, $value := $plainEnv }}
  - name: {{ $key }}
    value: {{ $value | quote }}
{{- end }}
{{- range $key, $value := $secretEnv }}
  - name: {{ $key }}
    valueFrom:
      secretKeyRef:
        name: {{ $value.secretName | quote }}
        key: {{ $value.key | quote }}
        optional: {{ default false $value.optional }}
{{- end }}
{{- with $extraEnv }}
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Volume mounts for a worker-class container: the shared config mounts
(mongo CA, onpremSettings, workload.extraVolumeMounts) plus per-worker mounts.
Call with (dict "root" $ "worker" <workerValues>).
*/}}
{{- define "docsie.workerVolumeMounts" -}}
{{- $root := .root -}}
{{- $worker := default (dict) .worker -}}
{{- $extra := concat (default (list) $root.Values.workload.extraVolumeMounts) (default (list) $worker.volumeMounts) -}}
{{- if or $root.Values.mongo.caSecretName $root.Values.onpremSettings.configMapName $extra }}
volumeMounts:
{{- if $root.Values.mongo.caSecretName }}
  - name: mongo-ca
    mountPath: {{ $root.Values.mongo.caMountPath }}
    readOnly: true
{{- end }}
{{- if $root.Values.onpremSettings.configMapName }}
  - name: onprem-settings
    mountPath: /app/config/settings/onprem.py
    subPath: {{ default "onprem.py" $root.Values.onpremSettings.fileName }}
    readOnly: true
{{- if $root.Values.onpremSettings.baseKey }}
  - name: onprem-settings
    mountPath: /app/config/settings/base.py
    subPath: {{ default "base.py" $root.Values.onpremSettings.baseFileName }}
    readOnly: true
{{- end }}
{{- end }}
{{- with $extra }}
{{ toYaml . | indent 2 }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Volumes for a worker-class pod: the shared config volumes plus per-worker
volumes. Call with (dict "root" $ "worker" <workerValues>).
*/}}
{{- define "docsie.workerVolumes" -}}
{{- $root := .root -}}
{{- $worker := default (dict) .worker -}}
{{- $extra := concat (default (list) $root.Values.workload.extraVolumes) (default (list) $worker.volumes) -}}
{{- if or $root.Values.mongo.caSecretName $root.Values.onpremSettings.configMapName $extra }}
volumes:
{{- if $root.Values.mongo.caSecretName }}
  - name: mongo-ca
    secret:
      secretName: {{ $root.Values.mongo.caSecretName }}
      items:
        - key: {{ $root.Values.mongo.caFileKey }}
          path: {{ $root.Values.mongo.caFileName }}
{{- end }}
{{- if $root.Values.onpremSettings.configMapName }}
  - name: onprem-settings
    configMap:
      name: {{ $root.Values.onpremSettings.configMapName }}
      items:
        - key: {{ default "onprem.py" $root.Values.onpremSettings.key }}
          path: {{ default "onprem.py" $root.Values.onpremSettings.fileName }}
{{- if $root.Values.onpremSettings.baseKey }}
        - key: {{ $root.Values.onpremSettings.baseKey }}
          path: {{ default "base.py" $root.Values.onpremSettings.baseFileName }}
{{- end }}
{{- end }}
{{- with $extra }}
{{ toYaml . | indent 2 }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "docsie.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: docsie
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Selector labels for a component
*/}}
{{- define "docsie.selectorLabels" -}}
app.kubernetes.io/name: docsie
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Pin application images by digest when the release supplies one. */}}
{{- define "docsie.image" -}}
{{- if .Values.image.digest -}}
{{ .Values.image.repository }}@{{ .Values.image.digest }}
{{- else -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end -}}
{{- end -}}

{{/* Wait for configured data services before importing Django settings. */}}
{{- define "docsie.startupDependencies" -}}
{{- if .Values.startupDependencies.enabled }}
initContainers:
  - name: wait-for-datastores
    image: {{ include "docsie.image" . | quote }}
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    command:
      - python
      - -c
      - |
        import os, socket, time
        from urllib.parse import urlsplit
        deadline = time.monotonic() + {{ .Values.startupDependencies.timeoutSeconds }}
        for key, default_port in [('DATABASE_URL', 5432), ('REDIS_URL', 6379)]:
            url = urlsplit(os.environ[key])
            while True:
                try:
                    with socket.create_connection((url.hostname, url.port or default_port), timeout=3):
                        break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise RuntimeError('Timed out waiting for ' + key) from None
                    time.sleep(2)
    envFrom:
      - secretRef:
          name: {{ include "docsie.secretName" . }}
      {{- with .Values.workload.extraEnvFrom }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
    resources:
      requests:
        cpu: 25m
        memory: 64Mi
      limits:
        cpu: "1"
        memory: 128Mi
{{- end }}
{{- end -}}
