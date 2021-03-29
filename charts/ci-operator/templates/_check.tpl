{{- define "ci-operator.missing.step" -}}
{{-   range $elem := .Values.additionalSteps }}
{{-     if not (or $elem.script $elem.command $elem.args) -}}
{{-       printf "[STEP]\tstep %s must contain command, args or script\n" $elem.name }}
{{-     end -}}
{{-   end -}}
{{- end -}}

{{- define "ci-operator.malformed.step" -}}
{{-   range $elem := .Values.additionalSteps }}
{{-     if and $elem.script (or $elem.command $elem.args) -}}
{{-       printf "[STEP]\tstep %s can not have script and args or command in the same time\n" $elem.name }}
{{-     end -}}
{{-   end -}}
{{- end -}}

{{- define "ci-operator.missing" -}}
{{- $missing := list -}}
{{- if and .Values.monitoring.enabled (not (.Capabilities.APIVersions.Has "monitoring.coreos.com/v1/ServiceMonitor")) -}}
{{- $missing := append $missing "" -}}
{{- end -}}
{{- $missing := append $missing (include "ci-operator.missing.step" .) -}}
{{- $missing := append $missing (include "ci-operator.malformed.step" .) -}}

{{- $missing := without $missing "" -}}
{{- $message := join "\n" $missing -}}

{{- if $message -}}
{{-   printf "\nMISSING :\n%s" $message | fail -}}
{{- end -}}

{{- end -}}
