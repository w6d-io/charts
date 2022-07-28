{{/* vim: set filetype=mustache: */}}
{{/*
Get the right workflow kind
Example:
kind: {{ include "common.workflow.kind" (dict "kind" .Values.kind) }}
*/}}
{{- define "common.workflow.kind" -}}
{{- $kind := .kind -}}
{{- if not (typeIs "string" $kind) -}}
{{- $kind = "" -}}
{{- end -}}
{{- $dictionary := dict "ds" "DaemonSet" "daemonset" "DaemonSet" "sts" "StatefulSet" "statefulset" "StatefulSet" "deploy" "Deployment" "deployment" "Deployment" "job" "Job" -}}
{{- default "Deployment" (get $dictionary (lower $kind)) -}}
{{- end -}}

{{/*
Create the name of the service account to use

Usage:
{{ include "common.serviceAccountName" . }}
*/}}
{{- define "common.serviceAccountName" -}}
{{- default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- end }}

{{/*
Create the name of the service account to use

Usage:
{{- include "common.workflow.env" (dict "env" .Values.path.to.env "secrets" .Values.path.to.secrets "configs" .Values.path.to.configs "context" $) | nindent 8}}
*/}}
{{- define "common.workflow.env" -}}
{{- $fullname := (include "common.names.fullname" .context)}}
{{- if or .env .configs .secrets }}
env:
{{- end }}
{{- if .Values.env -}}
{{- tpl .Values.env . | nindent 2 }}
{{- end }}

{{- with .secrets }}
{{- range . }}
  - name: {{ .name }}
    {{- if ne (default "env" .kind ) "volume" }}
    valueFrom:
      secretKeyRef:
        key: {{ .key }}
        name: {{ $fullname }}
    {{- else }}
    value: {{ .path }}/{{ .key }}
    {{- end }}
{{- end }}
{{- end }}

{{- with .configs }}
{{- range . }}
  - name: {{ .name }}
    value: {{ .path }}/{{ .key }}
{{- end }}
{{- end }}

{{- end -}}