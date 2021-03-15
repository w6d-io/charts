{{/*
Return pullSecretName
*/}}
{{- define "toucantoco-frontend.pullsecretname" -}}
{{- $fullname := (include "toucantoco-frontend.fullname" .) -}}
{{- if .Values.dockerSecret }}
{{- if .Values.dockerSecret.config }}
{{- printf "pull-%s" $fullname -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return imagePullSecrets
*/}}
{{- define "toucantoco-frontend.pullsecret" -}}
{{- $name := (include "toucantoco-frontend.pullsecretname" .) -}}
imagePullSecrets:
{{- with .Values.imagePullSecrets }}
{{- toYaml . }}
{{- end -}}
{{- if .Values.dockerSecret }}
{{- if .Values.dockerSecret.config }}
- name: {{ $name }}
{{- end -}}
{{- end -}}
{{- end -}}

