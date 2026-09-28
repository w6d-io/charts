{{/*
Sites (gatekit, site-operator, jinbe side) helpers.
*/}}

{{/*
Sites, maester Rules, operator Ingresses and the gateway all live in the release namespace
(maester watches only it).
*/}}
{{- define "auth.sites.namespace" -}}
{{- .Release.Namespace -}}
{{- end }}

{{- define "auth.gatekit.fullname" -}}
{{- printf "%s-gatekit" (include "auth.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "auth.gatekit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "auth.name" . }}-gatekit
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: gatekit
{{- end }}

{{/*
gatekit base URL: explicit sites.gatekitUrl, else the in-chart Service when gatekit is on.
*/}}
{{- define "auth.gatekit.url" -}}
{{- if .Values.sites.gatekitUrl -}}
{{- .Values.sites.gatekitUrl -}}
{{- else if .Values.gatekit.enabled -}}
{{- printf "http://%s:%d" (include "auth.gatekit.fullname" .) (int .Values.gatekit.service.port) -}}
{{- end -}}
{{- end }}

{{- define "auth.siteOperator.fullname" -}}
{{- printf "%s-site-operator" (include "auth.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "auth.siteOperator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "auth.name" . }}-site-operator
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: site-operator
{{- end }}

{{- define "auth.siteOperator.zonesConfigMap" -}}
{{- printf "%s-zones" (include "auth.siteOperator.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "auth.siteOperator.policyConfigMap" -}}
{{- printf "%s-policy" (include "auth.siteOperator.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Cluster-scoped object names (VAPs, ClusterRoles) carry the namespace so the sandbox and
the real stack can share a cluster.
*/}}
{{- define "auth.sites.clusterName" -}}
{{- printf "%s-%s" .ctx.Release.Namespace .name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "auth.sites.user" -}}
{{- printf "system:serviceaccount:%s:%s" .ctx.Release.Namespace .sa -}}
{{- end }}

{{/*
The Oathkeeper pod's ServiceAccount (the maester sidecar runs under it).
*/}}
{{- define "auth.oathkeeper.serviceAccountName" -}}
{{- $sa := (.Values.oathkeeper.deployment | default dict).serviceAccount | default dict -}}
{{- $sa.name | default (printf "%s-oathkeeper" .Release.Name) -}}
{{- end }}

{{/*
Validated oathkeeper.rules.source.
*/}}
{{- define "auth.oathkeeper.rulesSource" -}}
{{- $s := (.Values.oathkeeper.rules | default dict).source | default "legacy" -}}
{{- if not (has $s (list "legacy" "maester" "dual")) -}}
{{- fail (printf "oathkeeper.rules.source must be legacy, maester or dual (got %q)" $s) -}}
{{- end -}}
{{- $s -}}
{{- end }}

{{/*
Platform hosts no tenant site may take: sites.reservedHosts + every Oathkeeper proxy host.
*/}}
{{- define "auth.sites.reservedHosts" -}}
{{- $hosts := list -}}
{{- range .Values.sites.reservedHosts }}{{ $hosts = append $hosts . }}{{ end -}}
{{- range ((((.Values.oathkeeper.ingress | default dict).proxy | default dict).hosts) | default list) }}{{ $hosts = append $hosts .host }}{{ end -}}
{{- $hosts | uniq | sortAlpha | join "," -}}
{{- end }}

{{/*
Ingress annotations stamped by the operator, as k=v,k=v (sorted, deterministic).
*/}}
{{- define "auth.siteOperator.ingressAnnotations" -}}
{{- $out := list -}}
{{- range $k := (keys .Values.siteOperator.ingressAnnotations | sortAlpha) }}{{ $out = append $out (printf "%s=%s" $k (index $.Values.siteOperator.ingressAnnotations $k)) }}{{ end -}}
{{- join "," $out -}}
{{- end }}

{{/*
Jinbe env for Sites and observability (runtime only).
*/}}
{{- define "auth.jinbe.sitesEnv" -}}
- name: METRICS_PORT
  value: {{ .Values.jinbe.metrics.port | toString | quote }}
{{- if .Values.jinbe.metrics.token }}
- name: METRICS_TOKEN
  value: {{ .Values.jinbe.metrics.token | quote }}
{{- end }}
{{- if .Values.jinbe.env.OPA_TOKEN }}
- name: OPA_TOKEN
  value: {{ .Values.jinbe.env.OPA_TOKEN | quote }}
{{- end }}
{{- with .Values.jinbe.env.PROMETHEUS_URL }}
- name: PROMETHEUS_URL
  value: {{ . | quote }}
{{- end }}
{{- if .Values.jinbe.env.AUDIT_HMAC_KEY }}
- name: AUDIT_HMAC_KEY
  value: {{ .Values.jinbe.env.AUDIT_HMAC_KEY | quote }}
{{- end }}
{{- if .Values.jinbe.otel.enabled }}
- name: NODE_OPTIONS
  value: "--import ./dist/telemetry/register.js"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.jinbe.otel.endpoint | quote }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: {{ .Values.jinbe.otel.protocol | default "grpc" | quote }}
- name: OTEL_SERVICE_NAME
  value: {{ .Values.jinbe.otel.serviceName | default "jinbe" | quote }}
- name: OTEL_RESOURCE_ATTRIBUTES
  value: {{ printf "service.version=%s%s" (.Values.jinbe.image.tag | default .Chart.AppVersion) (ternary (printf ",%s" .Values.jinbe.otel.resourceAttributes) "" (ne (.Values.jinbe.otel.resourceAttributes | default "") "")) | quote }}
{{- end }}
{{- if .Values.sites.enabled }}
- name: SITES_KUBE
  value: "in-cluster"
- name: SITES_NAMESPACE
  value: {{ include "auth.sites.namespace" . | quote }}
{{- with include "auth.gatekit.url" . }}
- name: GATEKIT_URL
  value: {{ . | quote }}
{{- end }}
{{- with .Values.sites.zones }}
{{- $zones := list }}
{{- range . }}
{{- /* every Zone TLS mode serves a wildcard certificate (jinbe platform.ts) */}}
{{- $z := dict "suffix" .domain "wildcardTls" true }}
{{- if .cookieDomain }}{{ $_ := set $z "cookieDomain" .cookieDomain }}{{ end }}
{{- $zones = append $zones $z }}
{{- end }}
- name: SITES_ZONES
  value: {{ toJson $zones | quote }}
{{- end }}
{{- with include "auth.sites.reservedHosts" . }}
- name: SITES_RESERVED_HOSTS
  value: {{ . | quote }}
{{- end }}
{{- with .Values.sites.cookieDomain }}
- name: SITES_COOKIE_DOMAIN
  value: {{ . | quote }}
{{- end }}
{{- with .Values.sites.platformNamespaces }}
- name: SITES_PLATFORM_NAMESPACES
  value: {{ join "," . | quote }}
{{- end }}
- name: SITES_ACCESS_URL
  value: {{ .Values.sites.accessUrl | default (printf "https://%s/access" (include "auth.authDomain" .)) | quote }}
- name: GATEWAY_OATHKEEPER_CONFIGMAP
  value: {{ include "auth.jinbe.gatewayConfigMap" . | quote }}
- name: SITES_FOUR_EYES
  value: {{ .Values.sites.fourEyes | default "off" | quote }}
- name: SITES_SYNC_INTERVAL_MS
  value: {{ .Values.sites.syncIntervalMs | int64 | toString | quote }}
- name: SITES_RULES_LOADED_TIMEOUT_MS
  value: {{ .Values.sites.rulesLoadedTimeoutMs | int64 | toString | quote }}
{{- with .Values.sites.upstreamAllow }}
- name: SITES_UPSTREAM_ALLOW
  value: {{ join "," . | quote }}
{{- end }}
{{- with .Values.sites.env }}
- name: SITES_ENV
  value: {{ . | quote }}
{{- end }}
{{- range $name, $v := dict "SITES_PRODUCTION" .Values.sites.production "SITES_MIXED_GATEWAY" .Values.sites.mixedGateway }}
{{- $s := toString $v }}
{{- if not (has $s (list "" "<nil>")) }}
- name: {{ $name }}
  value: {{ $s | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- $cap := .Values.jinbe.captcha | default dict }}
{{- if or $cap.provider $cap.siteKey }}
- name: CAPTCHA_PROVIDER
  value: {{ $cap.provider | default "turnstile" | quote }}
{{- with $cap.siteKey }}
- name: CAPTCHA_SITE_KEY
  value: {{ . | quote }}
{{- end }}
- name: CAPTCHA_SECRET_KEY
  value: {{ $cap.secretKey | default (printf "vault:%s#CAPTCHA_SECRET_KEY" (required "jinbe.captcha.secretKey or jinbe.vaultPath is required when the captcha is configured" .Values.jinbe.vaultPath)) | quote }}
- name: CAPTCHA_EXPECTED_HOSTNAMES
  value: {{ $cap.expectedHostnames | default (include "auth.authDomain" .) | quote }}
{{- range $name, $v := dict "CAPTCHA_VERIFY_TIMEOUT_MS" $cap.verifyTimeoutMs "CAPTCHA_RECAPTCHA_MIN_SCORE" $cap.recaptchaMinScore "CAPTCHA_ALLOW_TEST_KEYS" $cap.allowTestKeys }}
{{- $s := toString $v }}
{{- if not (has $s (list "" "<nil>")) }}
- name: {{ $name }}
  value: {{ $s | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- $o := .Values.jinbe.observability | default dict }}
{{- range $name, $v := dict "LOKI_URL" $o.lokiUrl "LOKI_NAMESPACE" $o.lokiNamespace "LOKI_AUDIT_SELECTOR" $o.lokiAuditSelector "TEMPO_URL" $o.tempoUrl "GRAFANA_URL" $o.grafanaUrl "GRAFANA_LOKI_DATASOURCE_UID" $o.grafanaLokiDatasourceUid "GRAFANA_TEMPO_DATASOURCE_UID" $o.grafanaTempoDatasourceUid }}
{{- with $v }}
- name: {{ $name }}
  value: {{ . | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
A vendored CRD from files/crds, kept on uninstall: deleting the CRD would delete every
Site/Rule and take the gateway rules with it.
*/}}
{{- define "auth.sites.crd" -}}
{{- $crd := .ctx.Files.Get (printf "files/crds/%s" .file) | fromYaml -}}
{{- $ann := $crd.metadata.annotations | default dict -}}
{{- $_ := set $ann "helm.sh/resource-policy" "keep" -}}
{{- $_ := set $crd.metadata "annotations" $ann -}}
{{- $_ := set $crd.metadata "labels" (include "auth.labels" .ctx | fromYaml) -}}
{{ toYaml $crd }}
{{- end }}

{{/*
The public Sites rule (maester Rule spec shape, plus `id` for the file format). Works in
both the parent and the oathkeeper subchart context: only .Release and .Values.global plus
the oathkeeper values under .rules are read, passed in explicitly.
  dict "ctx" <root> "ok" <oathkeeper values>
*/}}
{{- define "auth.oathkeeper.publicSitesRule" -}}
{{- $g := .ctx.Values.global | default dict -}}
{{- $p := .ok.rules.publicSites -}}
{{- $auth := $g.authDomain | default (printf "auth.%s" $g.domain) -}}
{{- $up := $p.upstream | default (printf "http://%s-jinbe.%s.svc.cluster.local:8080" .ctx.Release.Name .ctx.Release.Namespace) -}}
{{- toJson (dict
    "match" (dict "url" (printf "<https?>://%s/api/public/sites/<.*>" $auth) "methods" (list "GET"))
    "upstream" (dict "url" $up "preserve_host" false)
    "authenticators" (list (dict "handler" ($p.authenticator | default "noop")))
    "authorizer" (dict "handler" "allow")
    "mutators" (list (dict "handler" "noop"))) -}}
{{- end }}

{{/*
Oathkeeper access_rules.repositories (subchart tpl context), rendered inside ONE single-quoted
list item of the toYaml'd config; extra items close the quote and start a new item at the
list's indent:
  legacy  — access-rules.json (+ inline:// public Sites rule when rules.publicSites is on)
  maester — access-rules.json (written by maester)
  dual    — access-rules.json (rules-sync) AND maester.json (maester)
The public Sites rule is inline only in legacy; in maester/dual it is a platform Rule, so it
is never loaded twice. The default render is a single file:// item, exactly as before.
*/}}
{{- define "auth.oathkeeper.repositories" -}}
{{- $s := .Values.rules.source | default "legacy" -}}
{{- print "file:///etc/rules/access-rules.json" -}}
{{- if eq $s "dual" -}}
{{- print "'\n  - 'file:///etc/rules/maester.json" -}}
{{- end -}}
{{- if and (.Values.rules.publicSites | default dict).enabled (eq $s "legacy") -}}
{{- $r := include "auth.oathkeeper.publicSitesRule" (dict "ctx" . "ok" .Values) | fromJson -}}
{{- $_ := set $r "id" "platform-public-sites" -}}
{{- printf "'\n  - 'inline://%s" (toJson (list $r) | b64enc) -}}
{{- end -}}
{{- end }}

{{/*
Name of the Oathkeeper config ConfigMap the subchart renders.
*/}}
{{- define "auth.oathkeeper.configMapName" -}}
{{- $ov := (((.Values.oathkeeper.oathkeeper | default dict).configFileOverride | default dict).nameOverride) -}}
{{- $ov | default (printf "%s-oathkeeper-config" .Release.Name) -}}
{{- end }}

{{- define "auth.oathkeeper.baseConfigMapName" -}}
{{- printf "%s-base" (include "auth.oathkeeper.configMapName" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Oathkeeper config jinbe's read-only gateway view reads: the chart-owned base when the
site-operator owns the rendered (and later versioned) config, else the subchart's own.
*/}}
{{- define "auth.jinbe.gatewayConfigMap" -}}
{{- if and .Values.siteOperator.enabled .Values.siteOperator.gateway.enabled -}}
{{- include "auth.oathkeeper.baseConfigMapName" . -}}
{{- else -}}
{{- include "auth.oathkeeper.configMapName" . -}}
{{- end -}}
{{- end }}
