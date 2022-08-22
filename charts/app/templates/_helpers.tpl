{{/* vim: set filetype=mustache: */}}

{{- define "ingress.host" -}}
{{- $defaultHost := printf "%s-%s.%s" .Values.name .Release.Namespace (include "global.domain" .) }}
{{- default $defaultHost .Values.ingress.host }}
{{- end }}
