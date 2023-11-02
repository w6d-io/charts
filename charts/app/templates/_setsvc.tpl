{{/*
Usage:
  {{ include "app.lifecycle.setsvc" (dict "service_name" .Values.service.name, "context" $) }}
*/}}
{{- define "app.lifecycle.setsvc" -}}
postStart:
  exec:
    command:
      - /init-tools/setsvc
      - {{ include "helper.names.service" (dict "name" .service_name "context" .context) }}
{{- end }}