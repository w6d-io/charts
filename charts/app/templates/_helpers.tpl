{{/* vim: set filetype=mustache: */}}

{{- define "service.name" -}}
{{- .Values.global.app.serviceName }}
{{- end }}

{{- define "service.port" -}}
{{- .Values.global.app.servicePort }}
{{- end }}

{{- define "ingress.host" -}}
{{- $defaultHost := printf "%s-%s.%s" "efact" (include "global.subdomain" .) (include "global.domain" .) }}
{{- default $defaultHost .Values.ingress.host }}
{{- end }}
