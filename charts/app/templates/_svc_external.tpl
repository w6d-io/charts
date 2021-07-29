{{/*
Return externalservicename
*/}}
{{- define "app.externalservicename" -}}
{{- printf "%s.%s.%s" (include "app.servicename" .) .Release.Namespace "svc.cluster.local" -}}
{{- end -}}

