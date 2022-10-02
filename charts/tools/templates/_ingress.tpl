{{/* vim: set filetype=mustache: */}}


{{/*
Generate backend entry that is compatible with all Kubernetes API versions.
Example:
{{- (include "tools.ingress.backend" (dict "serviceName" .Values.service.name "serviceTarget" .Values.service.externalPort "context" $)) | nindent 10 }}

Params:
  - serviceName - String. Name of an existing service backend
  - serviceTarget - String/Int. Port name (or number) of the service. It will be translated to different yaml depending if it is a string or an integer.
  - context - Dict - Required. The context for the template evaluation.
*/}}
{{- define "tools.ingress.backend" -}}
{{- $apiVersion := (include "tools.capabilities.ingress.apiVersion" .context) -}}
{{- if or (eq $apiVersion "extensions/v1beta1") (eq $apiVersion "networking.k8s.io/v1beta1") -}}
serviceName: {{ .serviceName }}
servicePort: {{ .serviceTarget }}
{{- else -}}
service:
  name: {{ .serviceName }}
  port:
    {{- if typeIs "string" .serviceTarget }}
    name: {{ .serviceTarget }}
    {{- else if or (typeIs "int" .serviceTarget) (typeIs "float64" .serviceTarget) }}
    number: {{ .serviceTarget | int }}
    {{- end }}
{{- end -}}
{{- end -}}


{{/*
Print "true" if the API pathType field is supported
Usage:
  {{ include "tools.ingress.supportsPathType" . }}
*/}}
{{- define "tools.ingress.supportsPathType" -}}
{{- $context := . -}}
{{- if (semverCompare "<1.18-0" (include "tools.capabilities.kubeVersion" $context)) -}}
{{- print "false" -}}
{{- else -}}
{{- print "true" -}}
{{- end -}}
{{- end -}}


{{/*
Usage:
  {{ include "tools.ingress.clusterIssuer" (dict "ingress" .Values.ingress) }}
*/}}
{{- define "tools.ingress.clusterIssuer" -}}
{{- if .ingress.clusterIssuer -}}
cert-manager.io/cluster-issuer: {{ .ingress.clusterIssuer | quote }}
{{- end -}}
{{- end -}}

{{/*
Usage:
  {{ include "tools.ingress.prefix" (dict "ingress" .Values.ingress) }}
*/}}
{{- define "tools.ingress.prefix" -}}
{{ default "nginx.ingress.kubernetes.io" .ingress.prefix }}
{{- end -}}


{{/*
Usage:
  {{ include "tools.ingress.annotations" (dict "ingress" .Values.ingress "context" $) }}
*/}}
{{- define "tools.ingress.annotations" -}}
{{- $prefix := (include "tools.ingress.prefix" (dict "ingress" .ingress)) -}}
externaldns: {{ default "disabled" .ingress.externaldns }}
{{- if and .ingress.class (eq (include "tools.ingress.supportsIngressClassname" .context) "false") }}
kubernetes.io/ingress.class: {{ .ingress.class }}
{{- end }}
{{ (include "tools.ingress.clusterIssuer" (dict "ingress" .ingress)) }}
{{- if .ingress.annotations }}
{{ toYaml .ingress.annotations }}
{{- end }}
kubernetes.io/tls-acme: {{ default "false" .ingress.tlsAcme | quote }}
{{ $prefix }}/ssl-redirect: {{ default "false" .ingress.sslRedirect | quote }}
{{- end -}}

{{/*
Returns true if the ingressClassname field is supported
Usage:
  {{ include "tools.ingress.supportsIngressClassname" . }}
*/}}
{{- define "tools.ingress.supportsIngressClassname" -}}
{{- if semverCompare "<1.18-0" (include "tools.capabilities.kubeVersion" .) -}}
{{- print "false" -}}
{{- else -}}
{{- print "true" -}}
{{- end -}}
{{- end -}}

{{/*
Example:
  {{- (include "tools.ingress.paths" (dict "paths" .Values.ingress.extraPaths "context" $)) | nindent 6 }}
example
paths:
  - serviceName: nginx
    serviceTarget: 8080       # can be a string
    path: /status           # optional default: "/"
*/}}
{{- define "tools.ingress.paths" -}}
{{- $context := .context -}}
{{- range $path := .paths }}
- path: {{ default "/" $path.path }}
  {{- if eq (include "tools.ingress.supportsPathType" $context) "true" }}
  pathType: Prefix
  {{- end }}
  backend:
  {{- include "tools.ingress.backend" (dict "serviceName" $path.serviceName "serviceTarget" $path.serviceTarget "context" $context) | nindent 4}}
{{- end }}
{{- end -}}

{{/*
Usage:
  {{- include "tools.ingress.className" (dict "ingress" .Values.ingress "context" $) | nindent 2}}
*/}}
{{- define "tools.ingress.className" -}}
{{- if eq (include "tools.ingress.supportsIngressClassname" .context) "true" -}}
ingressClassName: {{ (coalesce .ingress.className .ingress.class) | quote }}
{{- end -}}
{{- end -}}
