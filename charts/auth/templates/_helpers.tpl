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
Jinbe pod annotations — user-provided values + (when global.vault.enabled) the
banzai vault injector annotations. Used by both the Deployment and the
post-install Bootstrap Job so they share an identical Vault scope.
*/}}
{{- define "auth.jinbe.podAnnotations" -}}
{{- with .Values.jinbe.podAnnotations -}}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
Jinbe environment variables — runtime + bootstrap-required.
Included verbatim by templates/jinbe/deployment.yaml and
templates/jinbe/bootstrap-job.yaml so both pods share a single source of truth.

Bootstrap-only env (ADMIN_EMAIL/PASSWORD/NAME) is gated by
`if .Values.jinbe.env.ADMIN_*` — only emitted when explicitly set.
*/}}
{{- define "auth.jinbe.env" -}}
- name: NODE_ENV
  value: {{ .Values.jinbe.env.NODE_ENV | default "production" | quote }}
- name: APP_NAME
  value: {{ .Values.jinbe.env.APP_NAME | default "jinbe" | quote }}
- name: LOG_LEVEL
  value: {{ .Values.jinbe.env.LOG_LEVEL | default "info" | quote }}
- name: RELEASE_NAME
  value: {{ .Release.Name | quote }}
- name: APP_VERSION
  value: {{ .Values.jinbe.image.tag | default .Chart.AppVersion | quote }}
- name: COMMIT_SHA
  value: {{ .Values.jinbe.env.COMMIT_SHA | default (.Values.jinbe.image.tag | default .Chart.AppVersion) | quote }}
- name: REDIS_URL
  value: {{ .Values.jinbe.env.REDIS_URL | default (printf "redis://%s-redis-master:6379" .Release.Name) | quote }}
- name: KRATOS_PUBLIC_URL
  value: {{ .Values.jinbe.env.KRATOS_PUBLIC_URL | default (printf "http://%s-kratos-public:80" .Release.Name) | quote }}
- name: KRATOS_ADMIN_URL
  value: {{ .Values.jinbe.env.KRATOS_ADMIN_URL | default (printf "http://%s-kratos-admin:80" .Release.Name) | quote }}
- name: JINBE_INTERNAL_URL
  value: {{ .Values.jinbe.env.JINBE_INTERNAL_URL | default (printf "http://%s:%s" (include "auth.jinbe.fullname" .) (.Values.jinbe.service.port | toString)) | quote }}
- name: AUTH_DOMAIN
  value: {{ .Values.jinbe.env.AUTH_DOMAIN | default (include "auth.authDomain" .) | quote }}
- name: APP_DOMAIN
  value: {{ .Values.jinbe.env.APP_DOMAIN | default (include "auth.appDomain" .) | quote }}
- name: API_DOMAIN
  value: {{ .Values.jinbe.env.API_DOMAIN | default (include "auth.appDomain" .) | quote }}
- name: LOGIN_UI_URL
  value: {{ .Values.jinbe.env.LOGIN_UI_URL | default (printf "http://%s-kratos-login-ui:80" .Release.Name) | quote }}
- name: ADMIN_UI_URL
  value: {{ .Values.jinbe.env.ADMIN_UI_URL | default (printf "http://%s-admin-ui:80" .Release.Name) | quote }}
- name: ENCRYPTION_KEY
  value: {{ required "jinbe.env.ENCRYPTION_KEY is required" .Values.jinbe.env.ENCRYPTION_KEY | quote }}
{{- if .Values.jinbe.env.ADMIN_EMAIL }}
- name: ADMIN_EMAIL
  value: {{ .Values.jinbe.env.ADMIN_EMAIL | quote }}
{{- end }}
{{- if .Values.jinbe.env.ADMIN_PASSWORD }}
- name: ADMIN_PASSWORD
  value: {{ .Values.jinbe.env.ADMIN_PASSWORD | quote }}
{{- end }}
{{- if .Values.jinbe.env.ADMIN_NAME }}
- name: ADMIN_NAME
  value: {{ .Values.jinbe.env.ADMIN_NAME | quote }}
{{- end }}
{{- range $name, $value := .Values.jinbe.extraEnv }}
- name: {{ $name }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Jinbe runtime-only env — additions on top of auth.jinbe.env that the
API server needs but the Bootstrap Job does NOT. Included by deployment.yaml.
*/}}
{{- define "auth.jinbe.envRuntimeOnly" -}}
- name: PORT
  value: "3000"
- name: HOST
  value: "0.0.0.0"
- name: OPA_URL
  value: {{ .Values.jinbe.env.OPA_URL | default (printf "http://%s-opal-client:8181" .Release.Name) | quote }}
- name: OPAL_SERVER_URL
  value: {{ .Values.jinbe.env.OPAL_SERVER_URL | default (printf "http://%s-opal-server:7002" .Release.Name) | quote }}
- name: OPA_DATA_URL
  value: {{ .Values.jinbe.env.OPA_DATA_URL | default (printf "http://%s-opal-client:8181" .Release.Name) | quote }}
- name: CORS_ORIGIN
  value: {{ .Values.jinbe.env.CORS_ORIGIN | default (printf "https://%s,https://%s" (include "auth.appDomain" .) (include "auth.authDomain" .)) | quote }}
- name: ENABLE_SWAGGER
  value: {{ .Values.jinbe.env.ENABLE_SWAGGER | default "false" | quote }}
{{- if .Values.jinbe.env.DATABASE_URL }}
- name: DATABASE_URL
  value: {{ .Values.jinbe.env.DATABASE_URL | quote }}
{{- end }}
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
