{{/* vim: set filetype=mustache: */}}
{{/*
Kubernetes standard labels
*/}}
{{- define "helper.labels.standard" -}}
app.kubernetes.io/name: {{ include "helper.names.name" . }}
app.kubernetes.io/version: {{ default .Chart.AppVersion .Values.version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "helper.names.chart" . }}
{{- end -}}

{{/*
Labels to use on deploy.spec.selector.matchLabels and svc.spec.selector
*/}}
{{- define "helper.labels.matchLabels" -}}
app.kubernetes.io/name: {{ include "helper.names.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
