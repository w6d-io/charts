{{/* vim: set filetype=mustache: */}}
{{/*
 TENANT define
*/}}
{{- define "global.subdomain" -}}
{{- .Values.global.namespace -}}
{{- end -}}

{{- define "global.domain" -}}
{{- .Values.global.domain.name -}}
{{- end -}}

{{- define "global.domain.auth0" -}}
{{- .Values.global.domain.auth0 -}}
{{- end -}}

{{- define "global.domain.uam" -}}
{{- .Values.global.domain.uam -}}
{{- end -}}

{{- define "global.domain.eam" -}}
{{- .Values.global.domain.eam -}}
{{- end -}}

{{- define "global.domain.tms" -}}
{{- .Values.global.domain.tms -}}
{{- end -}}

{{- define "global.domain.graphql" -}}
{{- .Values.global.domain.graphql -}}
{{- end -}}

{{- define "global.kafka" -}}
{{- .Values.global.domain.kafka -}}
{{- end -}}

{{- define "global.id" -}}
{{- .Values.global.id -}}
{{- end -}}

{{- define "global.id_tenant" -}}
{{- .Values.global.id_tenant -}}
{{- end -}}

{{- define "global.id_organisation" -}}
{{- .Values.global.id_organisation -}}
{{- end -}}

{{- define "global.label" -}}
{{- .Values.global.label -}}
{{- end -}}

{{- define "global.database.host" -}}
{{ .Values.global.database.host }}
{{- end -}}

{{- define "global.database.database" -}}
{{- $name:=(printf "%s.%s" .Values.global.namespace (required "global.database.component is required" .Values.global.database.component)) -}}
{{ default $name .Values.global.database.name }}
{{- end -}}

{{- define "global.database.username" -}}
{{- $name:=(printf "%s_%s_app" .Values.global.namespace (include "common.component" .)) -}}
{{ default $name .Values.global.database.username }}
{{- end -}}

{{- define "global.database.adminuser" -}}
{{- $name:=(printf "%s_%s_admin" .Values.global.namespace (include "common.component" .)) -}}
{{ default $name .Values.global.database.adminuser }}
{{- end -}}

{{- define "global.database.password" -}}
{{ .Values.global.database.password }}
{{- end -}}

{{- define "global.database.adminpassword" -}}
{{ .Values.global.database.adminpassword }}
{{- end -}}

{{- define "global.database.postgres_password" -}}
{{ .Values.global.database.postgres_password }}
{{- end -}}

{{- define "global.env" -}}
- name: CUSTOMER_ID
  value: {{ .Values.global.id }}
{{- end -}}
{{/*
 TENANT define end
*/}}