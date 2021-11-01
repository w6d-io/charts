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

{{- define "oauth-external-auth.missing.oidc" -}}
{{-  if eq .Values.provider "oidc" }}
{{-    if not .Values.providerDisplayName  }}
{{-      print "[OIDC]\tProvider display must be set with oidc provider by providerDisplayName\n" }}
{{-    end }}
{{-    if not .Values.redirectUrl  }}
{{-      print "[OIDC]\tRedirect URL must be set with oidc provider by redirectUrl\n" }}
{{-    end }}
{{-    if not .Values.oidcIssuerUrl  }}
{{-      print "[OIDC]\tOIDC Issuer URL must be set with oidc provider by oidcIssuerUrl\n" }}
{{-    end }}
{{-  end }}
{{- end -}}

{{- define "oauth-external-auth.missing" -}}
{{- $missing := list -}}
{{- $missing := append $missing (include "oauth-external-auth.missing.client" .) -}}
{{- $missing := append $missing (include "oauth-external-auth.missing.cookie" .) -}}
{{- $missing := append $missing (include "oauth-external-auth.missing.oidc" .) -}}

{{- $missing := without $missing "" -}}
{{- $message := join "" $missing -}}

{{- if $message -}}
{{-   printf "\nMISSING :\n%s" $message | fail -}}
{{- end -}}

{{- end -}}
