

{{/*
 secret defines
*/}}

{{/*
Return secret volumeMounts
*/}}
{{- define "volumes.secretVolumeMounts" -}}
{{- if .Values.secrets -}}
{{- range $elem := .Values.secrets -}}
{{- if eq (coalesce $elem.kind "env" ) "volume" }}
- mountPath: {{ $elem.path }}/{{ $elem.key }}
  name: {{ $elem.name | lower | replace "_" "-" }}
  subPath: {{ $elem.key }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return secret volumes
*/}}
{{- define "volumes.secretVolumes" -}}
{{- $fullname := (include "global.names.fullname" .) -}}
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
 secret defines end
*/}}


{{/*
 confimap defines
*/}}

{{/*
Return configmap volumeMounts
*/}}
{{- define "volumes.configmapVolumeMounts" -}}
{{- if .Values.configs -}}
{{- range $elem := .Values.configs }}
- mountPath: {{ $elem.path }}/{{ $elem.key }}
  name: {{ $elem.name | lower | replace "_" "-" }}
  subPath: {{ $elem.key }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return configmap volumes
*/}}
{{- define "volumes.configmapVolumes" -}}
{{- $fullname := (include "global.names.fullname" .) -}}
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
 configmap defines end
*/}}
