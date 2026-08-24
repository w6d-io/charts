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
Jinbe pod annotations — user-provided values (jinbe.podAnnotations) merged with
the Banzai Cloud vault injector annotations (auth.vaultAnnotations) when
global.vault.enabled. Merged as a dict so a key never appears twice; on a key
collision the user's value wins. When vault is disabled auth.vaultAnnotations
renders empty and fromYaml yields an empty dict, so only user values remain.
Used by both the Deployment and the Bootstrap Job so they share an identical
Vault scope.
*/}}
{{- define "auth.jinbe.podAnnotations" -}}
{{- $vault := (include "auth.vaultAnnotations" . | fromYaml) | default dict -}}
{{- $user := .Values.jinbe.podAnnotations | default dict -}}
{{- $merged := merge (deepCopy $user) $vault -}}
{{- with $merged }}
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
{{ if  .Values.jinbe.enabled }}
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
{{/*
  Redis password: explicit jinbe.env.REDIS_PASSWORD wins; otherwise sourced
  from redis.auth.password when the bundled redis has auth enabled. Emitted
  BEFORE REDIS_URL so k8s $(REDIS_PASSWORD) expansion works inside the URL
  (jinbe's ioredis also reads REDIS_PASSWORD directly, which takes precedence).
*/}}
{{- $redisPass := "" -}}
{{- if .Values.jinbe.env.REDIS_PASSWORD -}}
{{- $redisPass = .Values.jinbe.env.REDIS_PASSWORD -}}
{{- else if and .Values.redis.enabled .Values.redis.auth.enabled -}}
{{- $redisPass = (.Values.redis.auth.password | default "") -}}
{{- end -}}
{{- if $redisPass }}
- name: REDIS_PASSWORD
  value: {{ $redisPass | quote }}
{{- end }}
- name: REDIS_URL
  value: {{ .Values.jinbe.env.REDIS_URL | default (printf "redis://%s%s-redis-master:6379" (ternary ":$(REDIS_PASSWORD)@" "" (ne $redisPass "")) .Release.Name) | quote }}
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
{{- /* API_DOMAIN deliberately has NO appDomain fallback: defaulting it to the
app domain made jinbe's bootstrap emit a catch-all gateway rule on the SAME
host as the kuma-* rules — Oathkeeper then 500s the whole host on every
request ("Expected exactly one rule but found multiple"). Only emitted when
the deployer explicitly serves the jinbe API on its own domain. */}}
{{- if .Values.jinbe.env.API_DOMAIN }}
- name: API_DOMAIN
  value: {{ .Values.jinbe.env.API_DOMAIN | quote }}
{{- end }}
- name: LOGIN_UI_URL
  value: {{ .Values.jinbe.env.LOGIN_UI_URL | default (printf "http://%s-kratos-login-ui:80" .Release.Name) | quote }}
- name: ADMIN_UI_URL
  value: {{ .Values.jinbe.env.ADMIN_UI_URL | default (printf "http://%s-admin-ui:80" .Release.Name) | quote }}
- name: ENCRYPTION_KEY
  value: {{ required "jinbe.env.ENCRYPTION_KEY is required" .Values.jinbe.env.ENCRYPTION_KEY | quote }}
# Audit event stream cap (Redis XADD MAXLEN ~). Shared by the API server and
# the bootstrap CLI so both trim the audit stream to the same bound.
- name: REDIS_AUDIT_MAXLEN
  value: {{ .Values.jinbe.env.REDIS_AUDIT_MAXLEN | default 100000 | quote }}
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
{{- if .Values.jinbe.k8s.enabled }}
- name: K8S_SA_AUTH_ENABLED
  value: {{.Values.jinbe.k8s.enabled | quote }}
- name: K8S_SA_TOKEN_AUDIENCE
  value: {{ .Values.jinbe.k8s.audience }}
- name: K8S_SA_EMAIL_DOMAIN
  value: {{ .Values.jinbe.k8s.email_domain }}
- name: K8S_SA_ALLOWED_SUBJECTS
  value: {{ .Values.jinbe.k8s.subjects }}
{{- end }}
{{- range $name, $value := .Values.jinbe.extraEnv }}
- name: {{ $name }}
  value: {{ $value | quote }}
{{- end }}
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
- name: OPA_AUTHZ_REMOTE
  value: {{ .Values.jinbe.env.OPA_AUTHZ_REMOTE | default (printf "http://%s:%s/v1/data/rbac/allow" (include "auth.opaAuthzProxy.fullname" .) (.Values.opaAuthzProxy.service.port | toString)) | quote }}
- name: SERVICE_DEFAULT_NAMESPACE
  value: {{ .Values.jinbe.env.SERVICE_DEFAULT_NAMESPACE | default .Release.Namespace | quote }}
- name: SERVICE_DEFAULT_DOMAIN
  value: {{ .Values.jinbe.env.SERVICE_DEFAULT_DOMAIN | default (include "auth.appDomain" .) | quote }}
- name: SERVICE_DEFAULT_PORT
  value: {{ .Values.jinbe.env.SERVICE_DEFAULT_PORT | default "8080" | quote }}
- name: CORS_ORIGIN
  value: {{ .Values.jinbe.env.CORS_ORIGIN | default (printf "https://%s,https://%s" (include "auth.appDomain" .) (include "auth.authDomain" .)) | quote }}
- name: ENABLE_SWAGGER
  value: {{ .Values.jinbe.env.ENABLE_SWAGGER | default "false" | quote }}
# Shared secret authenticating the Kratos web_hook that POSTs auth events to
# /api/webhooks/kratos. jinbe constant-time compares it against the request's
# `x-kratos-webhook-secret` header (or `Authorization: Bearer <secret>`). MUST
# equal the api_key value on the Kratos after-hooks (kratos.kratos.config
# selfservice flows). Default is a Vault reference — never a literal secret;
# override jinbe.env.KRATOS_WEBHOOK_SECRET and the Kratos hooks together.
- name: KRATOS_WEBHOOK_SECRET
  value: {{ .Values.jinbe.env.KRATOS_WEBHOOK_SECRET | default "vault:secret/data/auth#KRATOS_WEBHOOK_SECRET" | quote }}
{{- if .Values.jinbe.env.DATABASE_URL }}
- name: DATABASE_URL
  value: {{ .Values.jinbe.env.DATABASE_URL | quote }}
{{- end }}
{{- if .Values.jinbe.env.BACKUP_IMAGE_MONGO }}
- name: BACKUP_IMAGE_MONGO
  value: {{ .Values.jinbe.env.BACKUP_IMAGE_MONGO | quote }}
{{- end }}
{{- if .Values.jinbe.env.BACKUP_IMAGE_POSTGRES }}
- name: BACKUP_IMAGE_POSTGRES
  value: {{ .Values.jinbe.env.BACKUP_IMAGE_POSTGRES | quote }}
{{- end }}
{{- if .Values.jinbe.env.BACKUP_GCP_PROJECT_ID }}
- name: BACKUP_GCP_PROJECT_ID
  value: {{ .Values.jinbe.env.BACKUP_GCP_PROJECT_ID | quote }}
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

{{/*
Backup S3 env for jinbe (main + bootstrap). jinbe self-schedules the export
(no external CronJob) and reads the same S3 target so it can list/restore
snapshots and first-init can pull latest.json. Credentials come from the jinbe
ServiceAccount's IRSA annotation (no static keys).
*/}}
{{- define "auth.backup.env" -}}
- name: BACKUP_ENABLED
  value: {{ .Values.backup.enabled | quote }}
{{- if .Values.backup.enabled }}
- name: BACKUP_S3_BUCKET
  value: {{ required "backup.s3.bucket is required when backup.enabled=true" .Values.backup.s3.bucket | quote }}
- name: BACKUP_S3_PREFIX
  value: {{ .Values.backup.s3.prefix | default "auth-backup" | quote }}
- name: BACKUP_S3_REGION
  value: {{ .Values.backup.s3.region | default "eu-west-3" | quote }}
- name: BACKUP_SCHEDULE
  value: {{ .Values.backup.schedule | default "0 2 * * *" | quote }}
{{- end }}
{{- end }}

{{/*
Oathkeeper enabled-handler keys — comma-joined, deterministically sorted list of
the handler names in a given Oathkeeper handler map whose `enabled` is true.
Input context (.) is the handler map itself (authenticators / authorizers /
mutators / errors.handlers); it may be nil or absent, in which case an empty
string is returned. Helper for auth.oathkeeper.enabledEnv.
*/}}
{{- define "auth.oathkeeper.enabledKeys" -}}
{{- $handlers := . -}}
{{- $enabled := list -}}
{{- if $handlers -}}
{{- range $name := (keys $handlers | sortAlpha) -}}
{{- $handler := index $handlers $name -}}
{{- if kindIs "map" $handler -}}
{{- if $handler.enabled -}}
{{- $enabled = append $enabled $name -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- join "," $enabled -}}
{{- end }}

{{/*
Oathkeeper enabled-handler env vars for jinbe. Derives, from the chart's OWN
Oathkeeper config block (.Values.oathkeeper.oathkeeper.config), which handlers
are enabled per kind and exposes them so jinbe is the single source of truth for
the Gateway UI pickers and its fail-closed handler validation — no configmap
coupling, no drift.

Emitted only when Oathkeeper is enabled. Any section that is missing yields an
empty string (jinbe carries safe defaults). Included verbatim by
templates/jinbe/deployment.yaml and templates/jinbe/bootstrap-job.yaml.
*/}}
{{- define "auth.oathkeeper.enabledEnv" -}}
{{- if .Values.oathkeeper.enabled -}}
{{- $config := ((.Values.oathkeeper.oathkeeper | default dict).config | default dict) -}}
{{- $errors := ($config.errors | default dict) -}}
- name: OATHKEEPER_ENABLED_AUTHENTICATORS
  value: {{ include "auth.oathkeeper.enabledKeys" ($config.authenticators | default dict) | quote }}
- name: OATHKEEPER_ENABLED_AUTHORIZERS
  value: {{ include "auth.oathkeeper.enabledKeys" ($config.authorizers | default dict) | quote }}
- name: OATHKEEPER_ENABLED_MUTATORS
  value: {{ include "auth.oathkeeper.enabledKeys" ($config.mutators | default dict) | quote }}
- name: OATHKEEPER_ENABLED_ERROR_HANDLERS
  value: {{ include "auth.oathkeeper.enabledKeys" ($errors.handlers | default dict) | quote }}
{{- end -}}
{{- end }}
