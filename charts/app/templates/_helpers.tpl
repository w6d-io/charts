{{/* vim: set filetype=mustache: */}}

{{- define "ingress.host" -}}
{{- $defaultHost := printf "%s-%s.%s" .Values.name .Release.Namespace .Values.domain }}
{{- default $defaultHost .Values.ingress.host }}
{{- end }}

{{- define "database.component" -}}
{{ .Values.database.component }}
{{- end -}}

{{- define "app.names.name" -}}
{{- $name := printf "%s-%s" (include "database.component" .) .Chart.Name }}
{{- default $name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}



{{- define "app.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.version | default .Chart.AppVersion) }}
{{- end }}

{{- define "app.serviceAccountName" -}}
{{- default (include "app.names.name" .) .Values.serviceAccount.name }}
{{- end }}
