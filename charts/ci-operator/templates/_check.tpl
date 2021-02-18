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

{{- define "ci-operator.mandatory" -}}
{{- if .Values.webhook.enabled -}}
{{- if not (eq .Release.Namespace "ci-system") -}}
{{-   printf "\n\nMANDATORY:\nThe controller must be installed in ci-system namespace if webhook is enabled\n" | fail -}}
{{- end -}}
{{- end -}}
{{- end -}}
