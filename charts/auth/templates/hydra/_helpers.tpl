{{/*
The OAuth issuer host's public edge (hydra.edge).
*/}}

{{- define "auth.hydra.edgeHost" -}}
{{- .Values.hydra.edge.host | default (urlParse (include "auth.oauth.issuer" .)).host -}}
{{- end }}

{{/* Hydra's own public paths on the issuer host; anything else there is a 404. */}}
{{- define "auth.hydra.publicPaths" -}}
GET /oauth2/auth
POST /oauth2/token
POST /oauth2/revoke
GET /oauth2/sessions/logout
GET /oauth2/fallbacks/error
GET /.well-known/openid-configuration
GET /.well-known/jwks.json
{{- end }}

{{- define "auth.hydra.publicRouteName" -}}
{{- printf "%s-hydra-public" (include "auth.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
site-operator admission params for the one HTTPRoute allowed to reach Hydra (route_policy.yaml,
variable oauth2). Empty unless hydra.edge.httpRoute is on.
*/}}
{{- define "auth.hydra.edgeRouteParams" -}}
{{- if and .Values.hydra.enabled .Values.hydra.edge.httpRoute.enabled -}}
{{- $paths := list -}}
{{- range splitList "\n" (include "auth.hydra.publicPaths" .) }}{{ $paths = append $paths (last (splitList " " .)) }}{{ end -}}
oauth2PublicRoute: {{ include "auth.hydra.publicRouteName" . | quote }}
oauth2PublicHost: {{ include "auth.hydra.edgeHost" . | quote }}
oauth2PublicService: {{ printf "%s-hydra-public" .Release.Name | quote }}
oauth2PublicPort: "4444"
oauth2PublicPaths: {{ join "," $paths | quote }}
{{- end -}}
{{- end }}
