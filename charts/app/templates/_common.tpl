{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "common.component" -}}
{{ .Values.database.component }}
{{- end -}}

{{- define "common.names.name" -}}
{{- $name := printf "%s-%s" (include "common.component" .) .Chart.Name }}
{{- default $name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "common.names.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "common.names.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | lower | trimSuffix "-" -}}
{{- else -}}
{{- $shortname := printf "%s-%s" (include "common.component" .) .Chart.Name }}
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
{{ include "common.serviceAccountName" . }}
*/}}
{{- define "common.serviceAccountName" -}}
{{- default (include "common.names.name" .) .Values.serviceAccount.name }}
{{- end }}


{{- define "common.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.version | default .Chart.AppVersion) }}
{{- end }}
