{{/*
Admin API token sidecar for Kratos (kratos.adminAuth) and Hydra (hydra.adminAuth).

Nothing in the cluster enforces NetworkPolicy, so any pod can call the Kratos and Hydra admin APIs.
With adminAuth.enabled the admin listener binds 127.0.0.1 (serve.admin.host) and a small nginx in the
same pod listens on the pod IP at the SAME port — the Services' `targetPort: http-admin` and the
ServiceMonitor keep working unchanged — and forwards to loopback only requests carrying
`Authorization: Bearer <token>`. Open without a token: /health/{alive,ready} and /metrics/prometheus
(with or without the /admin prefix), for probes and scraping. The token is stripped before Kratos or
Hydra sees it.

The comparison is nginx's `map` on the whole header (a case-sensitive regex anchored on both ends):
not constant-time — nginx has no such primitive. With a 256-bit random token a timing oracle over the
network is not a practical attack; the token is restricted to [A-Za-z0-9_-] so it can never inject
config. The rendered config lives in /dev/shm (tmpfs, mode 0600) so the root filesystem stays
read-only, and the token is unset before nginx starts.

These templates are included from the subcharts' tpl-rendered values (deployment.extraContainers,
kratos/hydra.config), so `.Values` there is the subchart's: kratos.adminAuth / hydra.adminAuth.
*/}}

{{/* serve.admin.host: loopback while the sidecar fronts the admin port, else Kratos/Hydra's default. */}}
{{- define "auth.adminAuth.bindHost" -}}
{{- if (.Values.adminAuth | default dict).enabled }}127.0.0.1{{ end -}}
{{- end -}}

{{/* The Secret holding KRATOS_ADMIN_TOKEN / HYDRA_ADMIN_TOKEN (templates/admin-auth/secret.yaml renders it). */}}
{{- define "auth.adminAuth.secretName" -}}
{{- (.Values.adminAuth | default dict).secretName | default (printf "%s-admin-tokens" .Release.Name) -}}
{{- end -}}

{{/*
The sidecar container. Args: root (the subchart context), port (the admin port), key (the Secret key).
Token: adminAuth.token when set (e.g. a vault: reference resolved by vault-env in a Vault-annotated pod),
otherwise the Secret `auth.adminAuth.secretName` / adminAuth.secretKey (default: key).
*/}}
{{- define "auth.adminAuth.sidecar" -}}
{{- $cfg := .root.Values.adminAuth | default dict -}}
{{- if $cfg.enabled }}
- name: admin-auth
  image: {{ $cfg.image | default "nginxinc/nginx-unprivileged:1.27-alpine" | quote }}
  imagePullPolicy: IfNotPresent
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -eu
      case "${ADMIN_TOKEN:-}" in ''|*[!A-Za-z0-9_-]*) echo "admin-auth: ADMIN_TOKEN is empty or not a plain token; refusing to start" >&2; exit 1;; esac
      : "${POD_IP:?POD_IP is required}" "${LISTEN_PORT:?LISTEN_PORT is required}"
      umask 077
      C=/dev/shm/admin-auth.conf
      cat > "$C" <<CONF
      worker_processes 1;
      pid /dev/shm/nginx.pid;
      events { worker_connections 1024; }
      http {
        server_tokens off;
        client_body_temp_path /dev/shm/client_body;
        proxy_temp_path /dev/shm/proxy;
        fastcgi_temp_path /dev/shm/fastcgi;
        uwsgi_temp_path /dev/shm/uwsgi;
        scgi_temp_path /dev/shm/scgi;
        client_max_body_size 16m;
        log_format admin '\$remote_addr "\$request_method \$uri" \$status \$body_bytes_sent \$request_time auth=\$admin_auth';
        access_log /dev/stdout admin;
        map \$http_authorization \$admin_auth { default 0; "~^Bearer ${ADMIN_TOKEN}\$" 1; }
        upstream admin { server 127.0.0.1:${LISTEN_PORT}; keepalive 16; }
        server {
          listen ${POD_IP}:${LISTEN_PORT};
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_set_header Host \$host;
          proxy_set_header Authorization "";
          location ~ ^/(admin/)?(health/(alive|ready)|metrics/prometheus)\$ { access_log off; proxy_pass http://admin; }
          location / {
            default_type application/json;
            if (\$admin_auth = 0) { add_header WWW-Authenticate 'Bearer realm="admin"' always; return 401 '{"error":{"code":401,"status":"Unauthorized","message":"admin token required"}}'; }
            proxy_pass http://admin;
          }
        }
      }
      CONF
      unset ADMIN_TOKEN
      exec nginx -e stderr -c "$C" -g 'daemon off;'
  env:
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: LISTEN_PORT
      value: {{ .port | quote }}
    - name: ADMIN_TOKEN
      {{- if $cfg.token }}
      value: {{ $cfg.token | quote }}
      {{- else }}
      valueFrom:
        secretKeyRef:
          name: {{ include "auth.adminAuth.secretName" .root | quote }}
          key: {{ $cfg.secretKey | default .key | quote }}
      {{- end }}
  readinessProbe:
    tcpSocket:
      port: {{ .port }}
    periodSeconds: 10
  resources:
    {{- toYaml ($cfg.resources | default (dict "requests" (dict "cpu" "5m" "memory" "8Mi") "limits" (dict "memory" "32Mi"))) | nindent 4 }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    runAsGroup: 101
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: RuntimeDefault
{{- end }}
{{- end -}}

{{/*
Oathkeeper's oauth2_introspection calls Hydra's admin API: with oathkeeper.adminAuth.enabled it sends
the Hydra admin token, through Oathkeeper's config-by-env override of introspection_request_headers
(checked on oryd/oathkeeper:v25.4.0: merged over the file, introspection_url kept).
- adminAuth.tokenRef (a vault: reference): written inline as ${vault:…}, which vault-env resolves in
  the Vault-annotated Oathkeeper pod — no Secret holds the token.
- otherwise $(HYDRA_ADMIN_TOKEN), expanded by the kubelet from the Secret-backed env var above it.
Disabled, the override is `{}` (the default).
*/}}
{{- define "auth.adminAuth.introspectionHeaders" -}}
{{- $cfg := .Values.adminAuth | default dict -}}
{{- if and $cfg.enabled $cfg.tokenRef -}}
{{- if not (hasPrefix "vault:" $cfg.tokenRef) }}{{ fail "oathkeeper.adminAuth.tokenRef must be a vault: reference" }}{{ end -}}
{{- printf "{\"Authorization\":\"Bearer ${%s}\"}" $cfg.tokenRef -}}
{{- else if $cfg.enabled -}}
{"Authorization":"Bearer $(HYDRA_ADMIN_TOKEN)"}
{{- else -}}
{}
{{- end -}}
{{- end -}}
