{{/* vim: set filetype=mustache: */}}


{{/*
return the labels for aggregation from rule name
Usage:
{{- include "rbac.labels.aggregate" (dict "roleName" "my-role" "aggregations" .Values.aggregations ) | nindent 4}}
*/}}
{{- define "rbac.labels.aggregate" -}}
{{- $roleName := .roleName }}
{{- range $agg := .aggregations }}
{{- if (has $roleName $agg.roles) }}
rbac.w6d.io/aggregate-to-{{ $agg.name }}: "true"
{{- end }}
{{- end }}
{{- end -}}
