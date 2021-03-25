{{/* vim: set filetype=mustache: */}}

{{/*
Return pullSecretName
*/}}
{{- define "app.pullsecretname" -}}
{{- $fullname := (include "app.fullname" .) -}}
{{- if .Values.dockerSecret -}}
{{- printf "pull-%s" $fullname -}}
{{- else -}}
{{- range $elem := .Values.imagePullSecrets -}}
{{- $name := $elem.name -}}
{{- default "regcred" $name -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return imagePullSecrets
*/}}
{{- define "app.pullsecret" -}}
{{- $name := (include "app.pullsecretname" .) -}}
{{- if or .Values.imagePullSecrets .Values.dockerSecret -}}
imagePullSecrets:
- name: {{ $name }}
{{- end -}}
{{- end -}}
