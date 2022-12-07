{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "global.component" -}}
{{ .Values.database.component }}
{{- end -}}

{{- define "global.names.name" -}}
{{- $name := printf "%s-%s" (include "global.component" .) .Chart.Name }}
{{- default $name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "global.names.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "global.names.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | lower | trimSuffix "-" -}}
{{- else -}}
{{- $shortname := printf "%s-%s" (include "global.component" .) .Chart.Name }}
{{- $name := default $shortname .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | lower | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | lower | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
Usage:
{{ include "global.serviceAccountName" . }}
*/}}
{{- define "global.serviceAccountName" -}}
{{- default (include "global.names.name" .) .Values.serviceAccount.name }}
{{- end }}


{{- define "global.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.version | default .Chart.AppVersion) }}
{{- end }}
