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
OPA AuthZ Proxy fullname
*/}}
{{- define "auth.opaAuthzProxy.fullname" -}}
{{- printf "%s-opa-authz-proxy" (include "auth.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
OPA AuthZ Proxy selector labels
*/}}
{{- define "auth.opaAuthzProxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "auth.name" . }}-opa-authz-proxy
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: opa-authz-proxy
{{- end }}

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

{{/*
Jinbe fullname
*/}}
{{- define "auth.jinbe.fullname" -}}
{{- printf "%s-jinbe" (include "auth.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Jinbe service account
*/}}
{{- define "auth.jinbe.serviceAccountName" -}}
{{- replace "." "-" (default (include "auth.jinbe.fullname" .) .Values.jinbe.serviceAccount.name) -}}
{{- end }}


{{/*
Jinbe labels
*/}}
{{- define "auth.jinbe.labels" -}}
{{ include "auth.jinbe.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "auth.chart" . }}
{{- end }}

{{/*
Jinbe selector labels
*/}}
{{- define "auth.jinbe.selectorLabels" -}}
app.kubernetes.io/name: {{ include "auth.name" . }}-jinbe
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: jinbe
{{- end }}

{{/*
Auth domain
*/}}
{{- define "auth.authDomain" -}}
{{- printf "%s" (.Values.global.authDomain | default (printf "auth.%s" .Values.global.domain)) }}
{{- end }}

{{/*
App domain
*/}}
{{- define "auth.appDomain" -}}
{{- printf "%s" (.Values.global.appDomain | default (printf "app.%s" .Values.global.domain)) }}
{{- end }}
