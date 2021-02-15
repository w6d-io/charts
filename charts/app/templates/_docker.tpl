{{/*
Return pullSecretName
*/}}
{{- define "app.pullsecretname" -}}
{{- $fullname := (include "app.fullname" .) -}}
{{- if .Values.dockerSecret -}}
{{- printf "pull-%s" $fullname -}}
{{- end -}}
{{- end -}}

{{/*
Return imagePullSecrets
*/}}
{{- define "app.pullsecret" -}}
{{- $name := (include "app.pullsecretname" .) -}}
{{- if .Values.dockerSecret -}}
imagePullSecrets:
- name: {{ $name }}
{{- end -}}
{{- end -}}