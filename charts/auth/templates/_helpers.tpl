{{/*
Expand the name of the chart.
*/}}
{{- define "auth.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "auth.fullname" -}}
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
{{- define "auth.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "auth.labels" -}}
helm.sh/chart: {{ include "auth.chart" . }}
{{ include "auth.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "auth.selectorLabels" -}}
app.kubernetes.io/name: {{ include "auth.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
OPAL-static fullname
*/}}
{{- define "auth.opalStatic.fullname" -}}
{{- printf "%s-opal-static" (include "auth.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
OPAL-static selector labels
*/}}
{{- define "auth.opalStatic.selectorLabels" -}}
app.kubernetes.io/name: {{ include "auth.name" . }}-opal-static
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: opal-static
{{- end }}

{{/*
Webhook fullname
*/}}
{{- define "auth.webhook.fullname" -}}
{{- printf "%s-webhook" (include "auth.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Webhook selector labels
*/}}
{{- define "auth.webhook.selectorLabels" -}}
app.kubernetes.io/name: {{ include "auth.name" . }}-webhook
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: webhook
{{- end }}

{{/*
Access rules ConfigMap name
*/}}
{{- define "auth.accessRules.configMapName" -}}
{{- if .Values.oathkeeper.externalAccessRulesConfigMap -}}
{{- .Values.oathkeeper.externalAccessRulesConfigMap }}
{{- else -}}
{{- printf "%s-access-rules" (include "auth.fullname" .) }}
{{- end -}}
{{- end }}

{{/*
OPAL static data ConfigMap name
*/}}
{{- define "auth.opalStatic.configMapName" -}}
{{- if .Values.opalStatic.externalConfigMap -}}
{{- .Values.opalStatic.externalConfigMap }}
{{- else -}}
{{- printf "%s-opal-static-data" (include "auth.fullname" .) }}
{{- end -}}
{{- end }}

{{/*
Webhook ConfigMap name
*/}}
{{- define "auth.webhook.configMapName" -}}
{{- printf "%s-webhook-config" (include "auth.fullname" .) }}
{{- end }}

{{/*
Vault annotations for Banzai Cloud vault injector
*/}}
{{- define "auth.vaultAnnotations" -}}
{{- if .Values.global.vault.enabled -}}
vault.security.banzaicloud.io/vault-addr: {{ .Values.global.vault.address | quote }}
vault.security.banzaicloud.io/vault-role: {{ .Values.global.vault.role | quote }}
vault.security.banzaicloud.io/vault-skip-verify: "true"
{{- if .Values.global.vault.envFromPath }}
vault.security.banzaicloud.io/vault-env-from-path: {{ .Values.global.vault.envFromPath | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Kratos Login UI fullname
*/}}
{{- define "auth.kratosLoginUi.fullname" -}}
{{- printf "%s-kratos-login-ui" (include "auth.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Kratos Login UI selector labels
*/}}
{{- define "auth.kratosLoginUi.selectorLabels" -}}
app.kubernetes.io/name: {{ include "auth.name" . }}-kratos-login-ui
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: kratos-login-ui
{{- end }}

{{/*
Kratos Login UI image
*/}}
{{- define "auth.kratosLoginUi.image" -}}
{{- $tag := .Values.kratosLoginUi.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.kratosLoginUi.image.repository $tag }}
{{- end }}
