{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "dlm.component" -}}
{{ .Values.database.component }}
{{- end -}}

{{- define "dlm.names.name" -}}
{{- $name := .Chart.Name }}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dlm.names.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dlm.names.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | lower | trimSuffix "-" -}}
{{- else -}}
{{- $shortname := printf "%s-%s" (include "dlm.component" .) .Chart.Name }}
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
{{ include "dlm.serviceAccountName" . }}
*/}}
{{- define "dlm.serviceAccountName" -}}
{{- replace "." "-" (default (include "dlm.names.name" .) .Values.serviceAccount.name) -}}
{{- end }}

{{- define "dlm.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.version | default .Chart.AppVersion) }}
{{- end }}

{{- define "dlm.annotations.standard" -}}
{{- if .Values.vault.enabled -}}
vault.security.banzaicloud.io/vault-addr: {{ .Values.vault.url | quote }}
vault.security.banzaicloud.io/vault-role: {{ default (include "dlm.serviceAccountName" .) .Values.vault.role | quote }}
vault.security.banzaicloud.io/vault-skip-verify: "true"
{{- if .Values.vault.envFrom.enabled }}
vault.security.banzaicloud.io/vault-env-from-path: {{ printf "%s/%s" .Values.vault.envFrom.path (default (include "dlm.serviceAccountName" .) .Values.vault.role) }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "dlm.annotations.workload" -}}
{{- if .Values.linkerd.enabled -}}
linkerd.io/inject: "enabled"
{{- end -}}
{{- end -}}

{{- define  "dlm.annotations.defaultContainer" -}}
{{- if .Values.defaultContainer }}
kubectl.kubernetes.io/default-container: {{ include "dlm.names.name" $ }}
{{- end -}}
{{- end -}}
