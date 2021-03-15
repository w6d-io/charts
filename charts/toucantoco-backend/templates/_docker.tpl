{{/*
Return pullSecretName
*/}}
{{- define "toucantoco-backend.pullsecretname" -}}
{{- $fullname := (include "toucantoco-backend.fullname" .) -}}
{{- if .Values.dockerSecret }}
{{- if .Values.dockerSecret.config }}
{{- printf "pull-%s" $fullname -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return imagePullSecrets
*/}}
{{- define "toucantoco-backend.pullsecret" -}}
{{- $name := (include "toucantoco-backend.pullsecretname" .) -}}
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
