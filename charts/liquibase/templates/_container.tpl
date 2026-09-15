{{/* vim: set filetype=mustache: */}}
{{/*
  liquibase.container — renders the Liquibase migration container.

  Same `liquibase update` invocation in every mode; only the credential source and
  the target DB change. Used as an initContainer (app) or as the main container of a
  per-tenant Job (db-migrator).

  Call: {{ include "liquibase.container" (dict "ctx" $ "creds" "vault" ...) | nindent N }}
  See values.yaml for the full dict interface.
*/}}
{{- define "liquibase.container" -}}
{{- $ctx   := .ctx -}}
{{- $creds := default "secret" .creds -}}
{{- $image := include "liquibase.images.image" (dict "imageRoot" $ctx.Values.image "global" $ctx.Values.global) -}}
{{- $host  := default $ctx.Values.database.host .dbHost -}}
{{- $port  := default (default 5432 $ctx.Values.database.port) .dbPort -}}
{{- $name  := default $ctx.Values.database.name .dbName -}}
- name: liquibase
  image: {{ $image | quote }}
  imagePullPolicy: {{ default "" $ctx.Values.imagePullPolicy | quote }}
  {{- with $ctx.Values.liquibase.args }}
  args:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  env:
    - name: db_host
      value: {{ $host | quote }}
    - name: db_port
      value: {{ $port | quote }}
    - name: db_name
      value: {{ $name | quote }}
    - name: db_version
      value: {{ (coalesce $ctx.Values.dbversion $ctx.Values.version $ctx.Chart.AppVersion) | quote }}
    {{- if eq $creds "vault" }}
    # Resolved at container start by vault-env (banzaicloud vault-secrets-webhook).
    # The pod must carry the vault.security.banzaicloud.io/vault-role annotation.
    - name: db_username
      value: {{ required "userRef required in vault mode" .userRef | quote }}
    - name: db_password
      value: {{ required "passRef required in vault mode" .passRef | quote }}
    {{- else }}
    # secret mode (default): admin creds from the k8s secret provisioned by dlm.
    {{- $secretName := default (printf "%s-db" $ctx.Chart.Name) .secretName }}
    {{- $adminuser := default (default "postgres" $ctx.Values.database.adminuser) .adminuser }}
    - name: db_username
      value: {{ $adminuser | quote }}
    - name: db_admin_username
      value: {{ $adminuser | quote }}
    - name: db_password
      valueFrom:
        secretKeyRef:
          key: dlm-postgres-password
          name: {{ $secretName | quote }}
    - name: db_admin_password
      valueFrom:
        secretKeyRef:
          key: dlm-postgres-password
          name: {{ $secretName | quote }}
    {{- end }}
  command:
    - bash
    - -c
    - |
      set -e
      cd /db
      liquibase --url jdbc:postgresql://${db_host}:${db_port}/${db_name} \
        --username "${db_username}" \
        --password "${db_password}" \
        update
  {{- with $ctx.Values.liquibase.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
