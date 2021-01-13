{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the container image
*/}}
{{- define "app.image" -}}
{{- printf "%v:%v" .Values.image.repository .Values.image.tag | quote -}}
{{- end -}}


{{/*
Return servicename
*/}}
{{- define "app.servicename" -}}
{{- default .Release.Name .Values.service.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
Return secret volumeMounts
*/}}
{{- define "app.secretVolumeMounts" -}}
{{- if .Values.secrets -}}
{{- range $elem := .Values.secrets -}}
{{- if eq (coalesce $elem.kind "env" ) "volume" }}
{{- if eq (default "enabled" $elem.subPath) "enabled" }}
- mountPath: {{ $elem.path }}/{{ $elem.key }}
  name: {{ $elem.name | lower | replace "_" "-" }}
  subPath: {{ $elem.key }}
{{- else }}
- mountPath: {{ $elem.path }}
  name: {{ $elem.name | lower | replace "_" "-" }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return configmap volumeMounts
*/}}
{{- define "app.configmapVolumeMounts" -}}
{{- if .Values.configs -}}
{{- range $elem := .Values.configs }}
{{- if eq (default "enabled" $elem.subPath) "enabled" }}
- mountPath: {{ $elem.path }}/{{ $elem.key }}
  name: {{ $elem.name | lower | replace "_" "-" }}
  subPath: {{ $elem.key }}
{{- else }}
- mountPath: {{ $elem.path }}
  name: {{ $elem.name | lower | replace "_" "-" }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return secret volumes
*/}}
{{- define "app.secretVolumes" -}}
{{- $fullname := (include "app.fullname" .) -}}
{{- if .Values.secrets -}}
{{- range $elem := .Values.secrets -}}
{{- if eq ( coalesce $elem.kind "env" ) "volume" }}
- name: {{ $elem.name | lower | replace "_" "-" }}
  secret:
    secretName: {{ $fullname }}
{{- if $elem.mode }}
    defaultMode: {{ $elem.mode }}
{{- end }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return configmap volumes
*/}}
{{- define "app.configmapVolumes" -}}
{{- $fullname := (include "app.fullname" .) -}}
{{- if .Values.configs -}}
{{- range $elem := .Values.configs }}
- name: {{ $elem.name | lower | replace "_" "-" }}
  configMap:
    name: {{ $fullname }}
{{- if $elem.mode }}
    defaultMode: {{ $elem.mode }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}

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
