{{/* vim: set filetype=mustache: */}}

{{/*
Return volumeMounts
Usage:
  {{ include "common.volumes.volumeMounts" (dict "volumes" .Values.path.to.volumeMounts ) }}
Volume params:
  - path
  - name
  - subPath
Examples:
  {{ include "common.volumes.volumeMounts" (dict "volumes" (list (dict "path" "/data" "name" "config" "subPath" "config.yaml")) )}}
  {{ include "common.volumes.volumeMounts" (dict "volumes" (list (dict "path" "/data" "name" "config" "subPath" "")) )}}
*/}}
{{- define "common.volumes.volumeMounts" -}}
{{- range .volumes -}}
{{- $name := .name | lower | replace "_" "-" }}
- mountPath: {{ .path }}{{ if not (empty .subPath)}}/{{ .subPath }}{{ end }}
  name: {{ $name }}
  {{- if not (empty .subPath) }}
  subPath: {{ .subPath }}
  {{- end }}
  {{- end -}}
{{- end -}}

{{/*
Return volumes
Usage:
  {{ include "common.volumes.volumes" (dict "volumes" .Values.path.to.volumes "context" $) }}
Params:
  - fullname
  - volumes:
      Params:
      - name # use for volume name
      - mode # default mode
      - kind # secret, configMap, persistentVolumeClaim
      - claimName # optional : only for persistentVolumeClaim kind default is `name`
  - context
Examples:
  {{ include "common.volumes.volumes" (dict "fullname" $fullname "volumes" (list (dict "path" "/data" "name" "config" "subPath" "config.yaml" "kind" "configMap")) "context" $)}}
*/}}
{{- define "common.volumes.volumes" -}}
{{- $fullname := .fullname -}}
{{- range .volumes -}}
{{- if not (eq .kind "volumeClaimTemplates") -}}
{{- $name := .name | lower | replace "_" "-" }}
- name: {{ $name }}
  {{ .kind }}:{{ if eq .kind "emptyDir"}} {{ toYaml .options }}{{ end }}
  {{- if mustHas .kind (list "secret" "configMap") }}
    {{ get (dict "configMap" "name" "secret" "secretName") .kind }}: {{ $fullname }}{{if eq .kind "configMap" }}{{ printf "-%s"  $name }}{{ end }}
    {{- if .mode }}
    defaultMode: {{ .mode }}
    {{- end }}
  {{- end }}
  {{- if eq .kind "persistentVolumeClaim" }}
    claimName: {{default (printf "%s-%s" $fullname $name) .claimName}}
  {{- end }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Params:
  - name
  - kind # must be volumeClaimTemplate
  - mode
  - size
Usage:
  {{- include "common.volumes.volumeClaimTemplates" (dict "volumes" $volumes) | nindent 2 }}
*/}}
{{- define "common.volumes.volumeClaimTemplates" -}}
volumeClaimTemplates:
{{- range .volumes }}
{{- if eq .kind "volumeClaimTemplates" }}
- apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: {{ .name }}
  spec:
    accessModes:
    - {{ .mode }}
    resources:
      requests:
        storage: {{ .size }}
{{- end -}}
{{- end -}}
{{- end -}}