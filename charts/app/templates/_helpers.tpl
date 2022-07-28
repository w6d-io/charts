{{/* vim: set filetype=mustache: */}}

{{- define "ingress.host" -}}
{{- $defaultHost := printf "%s-%s.%s" .Values.name (include "global.subdomain" .) (include "global.domain" .) }}
{{- default $defaultHost .Values.ingress.host }}
{{- end }}
