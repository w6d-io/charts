{{/*
Expand the name of the chart.
*/}}
{{- define "toucantoco-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "toucantoco-backend.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "toucantoco-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "toucantoco-backend.labels" -}}
helm.sh/chart: {{ include "toucantoco-backend.chart" . }}
{{ include "toucantoco-backend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "toucantoco-backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "toucantoco-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "toucantoco-backend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "toucantoco-backend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create Redis address
*/}}
{{- define "toucantoco-backend.redis.address" -}}
{{- printf "%s-%s" .Release.Name "redis-master" }}
{{- end }}

{{/*
Create Redis port
*/}}
{{- define "toucantoco-backend.redis.port" -}}
6379
{{- end }}

{{/*
Create Redis secret
*/}}
{{- define "toucantoco-backend.redis.secret" -}}
{{- printf "%s-%s" .Release.Name "redis" }}
{{- end }}

{{/*
Create MongoDB address
*/}}
{{- define "toucantoco-backend.mongodb.address" -}}
{{- printf "%s-%s" .Release.Name "mongodb" }}
{{- end }}

{{/*
Create MongoDB port
*/}}
{{- define "toucantoco-backend.mongodb.port" -}}
27017
{{- end }}

{{/*
Create MongoDB user
*/}}
{{- define "toucantoco-backend.mongodb.user" -}}
{{- printf "%s" .Values.mongodb.user }}
{{- end }}

{{/*
Create MongoDB secret
*/}}
{{- define "toucantoco-backend.mongodb.secret" -}}
{{- printf "%s-%s" .Release.Name "mongodb" }}
{{- end }}

