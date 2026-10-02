{{/*
Superuser password env value (POSTGRES_PASSWORD in the pod, PGPASSWORD in the app-roles Job).
*/}}
{{- define "auth.postgresqlSimple.passwordValue" -}}
{{- $a := .Values.postgresqlSimple.auth }}
{{- if $a.passwordVaultRef }}
value: {{ $a.passwordVaultRef | quote }}
{{- else if $a.existingSecret }}
valueFrom:
  secretKeyRef:
    name: {{ $a.existingSecret }}
    key: {{ $a.existingSecretPasswordKey }}
{{- else }}
value: {{ $a.password | quote }}
{{- end }}
{{- end }}

{{/*
App role env: APP_ROLES ("role:db ...") and APP_ROLE_<n>_PASSWORD (literal or vault: reference,
resolved by vault-env in the pod).
*/}}
{{- define "auth.postgresqlSimple.appRolesEnv" -}}
{{- $roles := .Values.postgresqlSimple.appRoles.roles }}
- name: APP_ROLES
  value: {{ include "auth.postgresqlSimple.appRolesList" . | quote }}
{{- range $i, $r := $roles }}
- name: APP_ROLE_{{ $i }}_PASSWORD
  value: {{ required (printf "postgresqlSimple.appRoles.roles[%d].password is required" $i) $r.password | quote }}
{{- end }}
{{- end }}

{{- define "auth.postgresqlSimple.appRolesList" -}}
{{- $out := list }}
{{- range $i, $r := .Values.postgresqlSimple.appRoles.roles }}
{{- if not (regexMatch "^[a-z_][a-z0-9_]{0,62}$" ($r.name | default "")) }}{{ fail (printf "postgresqlSimple.appRoles.roles[%d].name must be a lowercase SQL identifier" $i) }}{{ end }}
{{- if not (regexMatch "^[a-z_][a-z0-9_]{0,62}$" ($r.database | default "")) }}{{ fail (printf "postgresqlSimple.appRoles.roles[%d].database must be a lowercase SQL identifier" $i) }}{{ end }}
{{- $out = append $out (printf "%s:%s" $r.name $r.database) }}
{{- end }}
{{- join " " $out }}
{{- end }}
