{{- define "ci-operator.missing" -}}
{{- $missing := list -}}
{{- if and .Values.monitoring.enabled (not (.Capabilities.APIVersions.Has "monitoring.coreos.com/v1/ServiceMonitor")) -}}
{{- $missing := append $missing "" -}}
{{- end -}}

{{- $missing := without $missing "" -}}
{{- $message := join "\n" $missing -}}

{{- if $message -}}
{{-   printf "\nMISSING DEPENDENCIES:\n%s" $message | fail -}}
{{- end -}}

{{- end -}}