{{- define "oauth-external-auth.missing.cookie" -}}
{{-   if and (not .Values.cookieSecret) (not .Values.secretName) }}
{{-     printf "[COOKIE]\tOAUTH2_PROXY_COOKIE_SECRET must be set either with cookieSecret in values or in secret through secretName\n"}}
{{-   end }}
{{- end -}}

{{- define "oauth-external-auth.missing.client" -}}
{{-   if not .Values.clientId }}
{{-     printf "[CLIENT]\tOAUTH2_PROXY_CLIENT_ID must be set with the clientId key in values\n"}}
{{-   end }}
{{-   if and (not .Values.clientSecret) (not .Values.secretName) }}
{{-     printf "[CLIENT]\tOAUTH2_PROXY_CLIENT_SECRET must be set either with clientSecret in values or in secret through secretName\n"}}
{{-   end }}
{{- end -}}

{{- define "oauth-external-auth.missing" -}}
{{- $missing := list -}}
{{- $missing := append $missing (include "oauth-external-auth.missing.client" .) -}}
{{- $missing := append $missing (include "oauth-external-auth.missing.cookie" .) -}}

{{- $missing := without $missing "" -}}
{{- $message := join "" $missing -}}

{{- if $message -}}
{{-   printf "\nMISSING :\n%s" $message | fail -}}
{{- end -}}

{{- end -}}
