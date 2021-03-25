{{/* vim: set filetype=mustache: */}}

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
Return configmap volumes
*/}}
{{- define "app.configmapVolumes" -}}
{{- $fullname := (include "app.fullname" .) -}}
{{- if .Values.configs -}}
{{- range $elem := .Values.configs }}
{{- $name := $elem.name | lower | replace "_" "-" }}
- name: {{ $name }}
  configMap:
    name: {{ printf "%s-%s" $fullname $name }}
    {{- if $elem.mode }}
    defaultMode: {{ $elem.mode }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}

