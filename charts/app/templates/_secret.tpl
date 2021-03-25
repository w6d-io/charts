{{/* vim: set filetype=mustache: */}}

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
Return secret volumes
*/}}
{{- define "app.secretVolumes" -}}
{{- $fullname := (include "app.fullname" .) }}
{{- if .Values.secrets }}
{{- range $elem := .Values.secrets }}
{{- if eq ( coalesce $elem.kind "env" ) "volume" }}
- name: {{ $elem.name | lower | replace "_" "-" }}
  secret:
    secretName: {{ $fullname }}
{{- if $elem.mode }}
    defaultMode: {{ $elem.mode }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

