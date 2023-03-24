{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "app.component" -}}
{{ .Values.database.component }}
{{- end -}}

{{- define "app.names.name" -}}
{{- $name := .Chart.Name }}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "app.names.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "app.names.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | lower | trimSuffix "-" -}}
{{- else -}}
{{- $shortname := printf "%s-%s" (include "app.component" .) .Chart.Name }}
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
{{ include "app.serviceAccountName" . }}
*/}}
{{- define "app.serviceAccountName" -}}
{{- default (include "app.names.name" .) .Values.serviceAccount.name }}
{{- end }}


{{- define "app.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.version | default .Chart.AppVersion) }}
{{- end }}

{{- define "app.annotations.standard" -}}
{{- if .Values.vault.enabled -}}
vault.security.banzaicloud.io/vault-addr: {{ .Values.vault.url | quote }}
vault.security.banzaicloud.io/vault-role: {{ default (include "app.serviceAccountName" .) .Values.vault.role | quote }}
vault.security.banzaicloud.io/vault-skip-verify: "true"
vault.security.banzaicloud.io/vault-role: {{ printf "strada/data/%s" (default (include "app.serviceAccountName" .) .Values.vault.role) }}
{{- end -}}
{{- end -}}