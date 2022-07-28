{{/* vim: set filetype=mustache: */}}

{{- define "liquibase.image" -}}
{{- printf "%s-db:%s" .Values.image.repository (coalesce .Values.dbversion .Values.version .Chart.AppVersion) }}
{{- end }}
