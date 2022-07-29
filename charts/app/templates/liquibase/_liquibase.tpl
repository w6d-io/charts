{{/* vim: set filetype=mustache: */}}

{{- define "liquibase.images.image" -}}
{{- $registryName := .imageRoot.registry -}}
{{- $repositoryName := .imageRoot.repository -}}
{{- $tag := .imageRoot.tag | toString -}}
{{- if .global }}
    {{- if .global.imageRegistry }}
     {{- $registryName = .global.imageRegistry -}}
    {{- end -}}
{{- end -}}
{{- if $registryName }}
{{- printf "%s/%s-db:%s" $registryName $repositoryName $tag -}}
{{- else -}}
{{- printf "%s-db:%s" $repositoryName $tag -}}
{{- end -}}
{{- end -}}

{{- define "liquibase.image" -}}
{{- printf "%s-db:%s" .Values.image.repository (coalesce .Values.dbversion .Values.version .Chart.AppVersion) }}
{{- end }}
