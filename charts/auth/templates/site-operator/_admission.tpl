{{/*
The site policies' parameters, as YAML (key: string). Rendered into the <release>-site-operator-policy
ConfigMap AND written inline into the policies' CEL (admission.yaml): the policies do not read a params
ConfigMap for data the chart already knows.
*/}}
{{- define "auth.siteOperator.policyParams" -}}
{{- $adm := .Values.siteOperator.admission }}
{{- $operator := include "auth.sites.user" (dict "ctx" . "sa" (include "auth.siteOperator.fullname" .)) }}
{{- $annotations := concat (keys .Values.siteOperator.ingressAnnotations) $adm.allowedIngressAnnotations }}
{{- if .Values.kratosGuard.selfServiceRateLimit.enabled }}
{{- $annotations = concat $annotations (list "nginx.ingress.kubernetes.io/limit-rpm" "nginx.ingress.kubernetes.io/limit-burst-multiplier") }}
{{- end }}
{{- $annotations = $annotations | uniq | sortAlpha }}
operatorUser: {{ $operator | quote }}
siteWriterUser: {{ include "auth.sites.user" (dict "ctx" . "sa" (include "auth.jinbe.serviceAccountName" .)) | quote }}
reservedHosts: {{ include "auth.sites.reservedHosts" . | quote }}
gatewayService: {{ printf "%s-oathkeeper-proxy" .Release.Name | quote }}
gatewayServicePort: http
allowedIngressAnnotations: {{ join "," $annotations | quote }}
allowedDefaultBackend: {{ $adm.allowedDefaultBackend | quote }}
allowedIngressAnnotationPrefixes: {{ join "," $adm.allowedIngressAnnotationPrefixes | quote }}
{{- if .Values.siteOperator.gatewayApi.enabled }}
allowedGateways: {{ join "," .Values.siteOperator.gatewayApi.gateways | quote }}
{{- end }}
{{- with (include "auth.hydra.edgeRouteParams" .) }}
# the OAuth issuer host's public route (hydra.edge): the one route that may reach Hydra
{{- . | nindent 0 }}
{{- end }}
allowedUpstream: {{ .Values.siteOperator.allowedUpstream | quote }}
deniedUpstream: {{ .Values.siteOperator.deniedUpstream | quote }}
ruleWriters: {{ prepend $adm.ruleWriters $operator | join "," | quote }}
ruleDeleters: {{ join "," $adm.ruleDeleters | quote }}
# maester runs as a sidecar under the Oathkeeper pod's ServiceAccount
maesterUsers: {{ include "auth.sites.user" (dict "ctx" . "sa" (include "auth.oathkeeper.serviceAccountName" .)) | quote }}
# empty: maester sidecar mode (Rules must not name a ConfigMap)
rulesConfigMap: ""
{{- if .Values.siteOperator.gateway.enabled }}
# Gateway: versioned configs <prefix>-<hash8> (operator-only, immutable), the volume whose
# configMap the operator may switch, the chart's seed config, the only Deployment it rolls
gatewayConfigPrefix: {{ include "auth.oathkeeper.configMapName" . | quote }}
gatewayConfigVolume: oathkeeper-config-volume
gatewayConfigSeed: {{ include "auth.oathkeeper.configMapName" . | quote }}
gatewayDeployment: {{ printf "%s-oathkeeper" .Release.Name | quote }}
{{- end }}
{{- end }}

{{/*
The Zone data the hosts policy needs, from sites.zones: the domains, and the TLS Secrets a Zone's
Ingress/ListenerSet uses, named as the operator names them (tls.mode secret -> tls.secretName,
issuer -> zone-<name>-tls, default -> none: the controller's default certificate).
*/}}
{{- define "auth.siteOperator.zoneParams" -}}
{{- $domains := list }}{{- $secrets := list }}
{{- range .Values.sites.zones }}
{{- $domains = append $domains (required "sites.zones[].domain is required" .domain) }}
{{- $tls := .tls | default dict }}
{{- if eq ($tls.mode | default "default") "secret" }}{{ $secrets = append $secrets (required "sites.zones[].tls.secretName is required with tls.mode secret" $tls.secretName) }}
{{- else if eq ($tls.mode | default "default") "issuer" }}{{ $secrets = append $secrets (printf "zone-%s-tls" .name) }}
{{- end }}
{{- end }}
domains: {{ $domains | uniq | sortAlpha | toJson }}
secrets: {{ $secrets | uniq | sortAlpha | toJson }}
{{- end }}

{{/* A CEL string literal: single-quoted, backslashes and quotes escaped. */}}
{{- define "auth.cel.string" -}}
'{{ . | replace "\\" "\\\\" | replace "'" "\\'" }}'
{{- end }}

{{/* A CEL list of string literals. */}}
{{- define "auth.cel.list" -}}
{{- $out := list }}{{ range . }}{{ $out = append $out (include "auth.cel.string" .) }}{{ end -}}
[{{ join ", " $out }}]
{{- end }}

{{/*
One policy CEL expression with every params.data.<key> of the policy ConfigMap written inline:
`params.data.?k` -> optional.of('<v>'), `params.data.k` -> '<v>'. A key the ConfigMap does not carry:
`params.data.?k` -> optional.none(); the OAuth issuer-route keys (read only behind the `oauth2` guard,
which is false without them) -> ''. Anything else left is a render error (admission.yaml).
*/}}
{{- define "auth.siteOperator.inlineExpr" -}}
{{- $e := .expr }}
{{- range $k, $v := .params }}
{{- $lit := include "auth.cel.string" (toString $v) }}
{{- $e = regexReplaceAllLiteral (printf "params\\.data\\.\\?%s\\b" $k) $e (printf "optional.of(%s)" $lit) }}
{{- $e = regexReplaceAllLiteral (printf "params\\.data\\.%s\\b" $k) $e $lit }}
{{- end }}
{{- $e = regexReplaceAllLiteral "params\\.data\\.\\?[A-Za-z0-9]+\\b" $e "optional.none()" }}
{{- $e = regexReplaceAllLiteral "params\\.data\\.oauth2Public(Route|Host|Service|Port|Paths)\\b" $e "''" }}
{{- $e -}}
{{- end }}
