{{/*
MCP server (auth-mcp) helpers.
*/}}

{{- define "auth.mcp.fullname" -}}
{{- printf "%s-mcp" (include "auth.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* The ServiceAccount jinbe accepts as the MCP actor (DELEGATED_ACTOR_SUBJECTS). */}}
{{- define "auth.mcp.serviceAccountName" -}}
{{- default "auth-mcp" .Values.mcp.serviceAccount.name -}}
{{- end }}

{{- define "auth.mcp.actorSubject" -}}
{{- printf "%s:%s" .Release.Namespace (include "auth.mcp.serviceAccountName" .) -}}
{{- end }}

{{- define "auth.mcp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "auth.name" . }}-mcp
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: mcp
{{- end }}

{{- define "auth.mcp.host" -}}
{{- .Values.mcp.host | default (printf "mcp.%s" .Values.global.domain) -}}
{{- end }}

{{/* The public URL of /mcp: token audience (RFC 8707), PRM `resource`, and the address people are shown. */}}
{{- define "auth.mcp.publicUrl" -}}
{{- printf "https://%s/%s" (include "auth.mcp.host" .) (trimPrefix "/" .Values.mcp.path) -}}
{{- end }}

{{- define "auth.mcp.upstreamUrl" -}}
{{- printf "http://%s:%d" (include "auth.mcp.fullname" .) (int .Values.mcp.service.port) -}}
{{- end }}

{{/*
jinbe's ServiceAccount allow-list: jinbe.k8s.subjects, plus auth-mcp when mcp is on. With
jinbe.k8s.enabled and no subjects (no filter) it stays empty: adding auth-mcp would narrow it.
*/}}
{{- define "auth.jinbe.k8sSubjects" -}}
{{- $subjects := .Values.jinbe.k8s.subjects | default "" -}}
{{- if and .Values.mcp.enabled (or (not .Values.jinbe.k8s.enabled) $subjects) -}}
{{- $subjects = trimPrefix "," (printf "%s,%s" $subjects (include "auth.mcp.actorSubject" .)) -}}
{{- end -}}
{{- $subjects -}}
{{- end }}

{{/*
jinbe env with mcp on (main container, bootstrap init container and Job): delegated tokens for the
MCP audience from the auth-mcp actor, the address kuma shows (MCP_PUBLIC_URL, until an administrator
saves another), bootstrap's Oathkeeper rule `mcp` to the in-chart Service (MCP_UPSTREAM_URL), and the
OAuth sign-in (MCP_OAUTH_*: bootstrap emits the rule `mcp-oauth-as` on the issuer host).
DELEGATED_TOKENS_ENABLED is only the ceiling: MCP stays off until an administrator turns it on.
*/}}
{{- define "auth.mcp.jinbeEnv" -}}
{{- if .Values.mcp.enabled }}
- name: DELEGATED_TOKENS_ENABLED
  value: "true"
- name: DELEGATED_TOKEN_AUDIENCE
  value: {{ include "auth.mcp.publicUrl" . | quote }}
- name: DELEGATED_ACTOR_SUBJECTS
  value: {{ include "auth.mcp.actorSubject" . | quote }}
- name: MCP_PUBLIC_URL
  value: {{ include "auth.mcp.publicUrl" . | quote }}
- name: MCP_UPSTREAM_URL
  value: {{ include "auth.mcp.upstreamUrl" . | quote }}
{{- /* RFC 8414 metadata jinbe serves on the issuer host: its `issuer` must equal auth-mcp's HYDRA_ISSUER */}}
- name: MCP_OAUTH_ISSUER
  value: {{ include "auth.oauth.issuer" . | quote }}
{{- with .Values.mcp.oauth.dcrRate }}
- name: MCP_OAUTH_DCR_RATE
  value: {{ . | quote }}
{{- end }}
{{- with .Values.mcp.oauth.providerCeiling }}
- name: MCP_OAUTH_PROVIDER_CEILING
  value: {{ . | quote }}
{{- end }}
{{- end }}
{{- end }}
