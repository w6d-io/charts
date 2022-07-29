{{/*
Return the appropriate apiVersion for Ingress.
*/}}
{{- define "ingress.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "networking.k8s.io/v1/Ingress" -}}
{{- print "networking.k8s.io/v1" -}}
{{- else if .Capabilities.APIVersions.Has "networking.k8s.io/v1beta1/Ingress" -}}
{{- print "networking.k8s.io/v1beta1" -}}
{{- else -}}
{{- print "extensions/v1beta1" -}}
{{- end -}}
{{- end -}}

{{- define "ingress.extra.paths" -}}
{{- range .Values.ingress.extraPaths }}
{{- $name := "" }}
{{- $port := 0 }}
{{- if hasKey .backend "service" }}
{{- $name = .backend.service.name }}
{{- $port = .backend.service.port.number }}
{{- else }}
{{- $name = .backend.serviceName }}
{{- $port = .backend.servicePort }}
{{- end }}
- path: {{ default "/" .path }}
  backend:
  {{- if $.Capabilities.APIVersions.Has "networking.k8s.io/v1/Ingress" }}
    service:
      name: {{ $name }}
      port:
        number: {{ $port }}
  pathType: Prefix
  {{- else }}
    serviceName: {{ $name }}
    servicePort: {{ $port }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "ingress.className" -}}
{{- if .Capabilities.APIVersions.Has "networking.k8s.io/v1/Ingress" -}}
{{- if or .Values.ingress.className .Values.ingress.class -}}
ingressClassName: {{ coalesce .Values.ingress.className .Values.ingress.class }}
{{- end -}}
{{- end -}}
{{- end -}}
