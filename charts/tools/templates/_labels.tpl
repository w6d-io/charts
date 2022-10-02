{{/* vim: set filetype=mustache: */}}
{{/*
Kubernetes standard labels
*/}}
{{- define "tools.labels.standard" -}}
app.kubernetes.io/name: {{ include "tools.names.name" . }}
app.kubernetes.io/version: {{ default .Chart.AppVersion .Values.version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "tools.names.chart" . }}
{{- end -}}

{{/*
Labels to use on deploy.spec.selector.matchLabels and svc.spec.selector
*/}}
{{- define "tools.labels.matchLabels" -}}
app.kubernetes.io/name: {{ include "tools.names.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
