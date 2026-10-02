# auth: the W6D identity and access stack

One Helm release that gives a cluster sign-in, an API gateway, fine-grained authorization and an admin
console: Ory Kratos (identity), Ory Oathkeeper (gateway), OPA fed by OPAL (policy), and **jinbe**,
the control plane that holds the access model and drives the others. The optional components add
OAuth sign-in for MCP clients (Hydra and auth-mcp) and self-service publishing of protected sites
(site-operator and gatekit).

> An AI assistant helping with this chart should read [LLM.md](LLM.md) first.

- [Components](#components)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Secrets and Vault](#secrets-and-vault)
- [Backup and restore](#backup-and-restore)
- [Authorization model](#authorization-model)
- [GitOps with Argo CD](#gitops-with-argo-cd)
- [Upgrading](#upgrading)
- [Values reference](#values-reference)
- [Troubleshooting](#troubleshooting)

---

## Components

| Component | What it does | Enabled by default | Key |
|---|---|---|---|
| **Kratos** (Ory) | Identities, sessions, password / code / passkey / TOTP sign-in, recovery, verification. Courier StatefulSet sends the emails. | yes | `kratos` |
| **Oathkeeper** (Ory) | The gateway behind your Envoy Gateway or ingress: authenticates every request (Kratos session or OAuth2 token), asks OPA, and mutates identity headers. | yes | `oathkeeper` |
| **jinbe** | Access-model control plane: groups, roles, org roles, per-person grants, sites, audit. Publishes data to OPAL and gateway rules to Oathkeeper. Runs a bootstrap init container. | yes | `jinbe` |
| **kuma** | The admin console (people, groups, organisations, sites, settings, audit, backup). | yes | `adminUi` |
| **kratos-login-ui** | The sign-in, sign-up, recovery, 2FA, step-up and OAuth consent pages. | yes | `kratosLoginUi` |
| **OPAL server and client (with OPA)** | OPAL server pulls the policy repo and jinbe's data, then pushes both to the OPA embedded in the OPAL client. | yes | `opal` |
| **opa-authz-proxy** | Turns OPA's answer into the HTTP status Oathkeeper's `remote_json` authorizer expects (200 / 403), and emits the `X-User-*` role headers from the rich decision. | yes | `opaAuthzProxy` |
| **Redis** (Bitnami) | jinbe's store (access model, audit stream, bootstrap marker), and OPAL's broadcast bus when scaled. | yes | `redis` |
| **Postgres** (`postgresqlSimple`) | Kratos's database (and Hydra's), with TLS, `pg_hba` and per-app roles. | yes | `postgresqlSimple` |
| **error-page** | The 401 / 403 / 404 pages served on the same host. | yes | `errorPage` |
| **Hydra** (Ory) | OAuth2 / OIDC server: MCP client sign-in, client credentials for API keys. | no | `hydra` |
| **auth-mcp** | MCP server that exposes the console's actions to AI clients, acting for the signed-in person. | no | `mcp` |
| **hydrator** | Oathkeeper `hydrator` mutator backend (organisation lookup on sign-up). | no | `hydrator` |
| **site-operator** | Turns `Site` and `Zone` custom resources into HTTPRoutes or Ingresses, certificates and Oathkeeper rules, guarded by ValidatingAdmissionPolicies. | no | `siteOperator` |
| **gatekit** | Validates site drafts against the gateway (route overlap, matcher parity) before jinbe applies them. | no | `gatekit` |

The images are public: `ghcr.io/w6d-io/{jinbe,kuma,kratos-login-ui,auth-mcp,gatekit,site-operator}`,
`ghcr.io/w6d-io/infra/opa-authz-proxy`, and the Ory, OPAL, Postgres and Redis upstream images.

## Architecture

```mermaid
flowchart LR
  B[Browser / API client] -->|HTTPS| EG[Envoy Gateway<br/>or ingress-nginx]
  EG --> OK[Oathkeeper proxy]
  OK -->|session check| KR[Kratos]
  OK -->|remote_json| PX[opa-authz-proxy]
  PX -->|/v1/data/rbac/allow<br/>/v1/data/rbac/decision| OPA[OPA in opal-client]
  OK -->|allowed| UP[kuma / jinbe API / login-ui / your sites]
  J[jinbe] -->|data updates| OS[OPAL server]
  OS -->|websocket push| OPA
  OS -->|fetches entries| J
  OS -->|git pull| PR[(policy repo)]
  J --- R[(Redis)]
  KR --- PG[(Postgres)]
  J -->|gateway rules| OK
  KR -->|audit / guard web hooks| J
```

**A request:** Envoy Gateway → Oathkeeper (matches a rule, authenticates the Kratos session cookie or an
OAuth2 bearer, then calls the authorizer) → opa-authz-proxy → OPA (`rbac.allow`, or `rbac.decision` when a
site wants role headers) → 200 / 403 → the upstream, with `X-User-*` headers that Oathkeeper sets. A browser
without a session is redirected to `https://<authDomain>/login`.

**A change:** an admin edits access in kuma → jinbe writes Redis and publishes the new data to the OPAL server →
the OPAL server pushes it to every OPA. Policy code (`rbac.rego`) comes from the policy repository the OPAL server
polls (`opal.server.policyRepoUrl`, branch `policyRepoMainBranch`).

**Gateway rules:** jinbe serves the platform rules (sign-in pages, console, API) at `/api/oathkeeper/rules`, and
Oathkeeper loads them. With `oathkeeper.rules.source: dual` (Sites), the oathkeeper-maester sidecar also loads the
`Rule` resources that site-operator writes.

## Prerequisites

| Need | Why | Notes |
|---|---|---|
| Kubernetes **>= 1.30** | `ValidatingAdmissionPolicy` v1 (site-operator), restricted Pod Security everywhere | Run the namespace with `pod-security.kubernetes.io/enforce: restricted`: every in-chart workload complies. |
| **Gateway API v1** with **Envoy Gateway**, or ingress-nginx | Exposes the platform hosts | `oathkeeper.edge.httpRoute` (Gateway API) or `oathkeeper.ingress.proxy` (Ingress). site-operator zones on a Gateway use `ListenerSet` (Gateway API experimental channel). |
| **cert-manager** | TLS for the hosts, and per-site certificates (site-operator) | The Gateway's listener needs a certificate covering `<authDomain>` and `<appDomain>`. |
| **Vault + the Bank-Vaults webhook** (`vault-secrets-webhook`, vault-env) | Every secret is a `vault:<path>#<KEY>` reference that vault-env resolves **inside the pod**, at start | A Kubernetes-auth role bound to the namespace's service accounts. See [Secrets and Vault](#secrets-and-vault). Literal values work for local tests only. |
| **DNS** | `<authDomain>` (sign-in) and `<appDomain>` (console and API) point at the gateway | Add `hydra.<domain>` (Hydra issuer) and `mcp.<domain>` when those are on. |
| A **Git policy repo** | `rbac.rego`, loaded by OPAL | Default `https://github.com/w6d-io/policies.git`. It must use the `import rego.v1` syntax. |
| SMTP | Kratos courier (codes, recovery, verification) | `COURIER_SMTP_CONNECTION_URI`. |
| Optional: **S3 bucket + IRSA** (EKS) | RBAC backups, and the rollback snapshot of an access-model move | See [Backup and restore](#backup-and-restore). |
| Optional: Prometheus Operator | `ServiceMonitor`s (`observability.serviceMonitors`) | |

## Getting started

From an empty namespace to a signed-in super admin, with the bundled Postgres and Redis and every secret
in Vault. The full values file is [`examples/minimal-values.yaml`](examples/minimal-values.yaml).

The order matters on a fresh install (and on a rebuild after deleting the namespace):

1. **Vault keys first**: every key in [the table](#secrets-and-vault), including the app-role passwords
   (`KRATOS_APP_PASSWORD`, `HYDRA_APP_PASSWORD` with Hydra) and `OPA_DECISION_TOKEN`. A pod whose key is missing
   does not start.
2. **Namespace labels**: the label your Gateway's `allowedListeners` selects (when site zones attach a
   ListenerSet to it), and the Pod Security labels. With Argo CD, put them in `managedNamespaceMetadata`
   ([GitOps](#gitops-with-argo-cd)), so a recreated namespace gets them before anything else.
3. **Install or sync.**
4. **Check the first jinbe pod's bootstrap log** (step 7) before anything restarts it.

On a rebuild with the backup on, decide first what the first bootstrap does with the backup
(`backup.restoreOnFirstInit`, [Backup](#backup-and-restore)): `"false"` for a deliberate blank rebuild,
`"true"` for disaster recovery (restore or fail), `auto` (default) to restore when a backup exists.

### 1. Pick names

- Domain `example.com`: sign-in at `auth.example.com`, console and API at `app.example.com`.
- Namespace `auth`, release name `auth`. Service names are prefixed with the release name: `auth-postgresql`, `auth-jinbe`, and so on.
- Vault KV v2 path `secret/data/auth` (mount `secret`), Kubernetes-auth role `auth`.

### 2. Vault role

Bind the role to the service accounts that run vault-env in the release namespace:

```sh
vault write auth/kubernetes/role/auth \
  bound_service_account_names=default,kratos,auth-jinbe \
  bound_service_account_namespaces=auth \
  policies=auth-read ttl=1h
# auth-read: path "secret/data/auth" { capabilities = ["read"] }
```

Add `auth-oathkeeper` (when `oathkeeper.adminAuth.tokenRef` is set) and `auth-hydra` and `auth-hydra-job`
(Hydra), if you turn those on.

### 3. Write the secrets

Generate every value without echoing it. **Always `vault kv patch`**: `kv put` replaces the whole path
and deletes every other key.

```sh
p() { vault kv patch -mount=secret auth "$@" >/dev/null; }
hex() { openssl rand -hex "$1"; }

p ENCRYPTION_KEY="$(hex 32)" KRATOS_WEBHOOK_SECRET="$(hex 32)" ADMIN_PASSWORD="$(openssl rand -base64 24)"
p KRATOS_SECRETS_DEFAULT="$(hex 32)" KRATOS_SECRETS_COOKIE="$(hex 32)" KRATOS_SECRETS_CIPHER="$(hex 16)"
p PG_SUPERUSER_PASSWORD="$(hex 24)" REDIS_PASSWORD="$(hex 24)" OPA_ROOT_TOKEN="$(hex 32)" OPA_DECISION_TOKEN="$(hex 32)"

# Each app role and its DSN share one password (postgresqlSimple.appRoles creates the role at initdb)
KP="$(hex 24)"
p KRATOS_APP_PASSWORD="$KP" KRATOS_DSN="postgresql://kratos_app:${KP}@auth-postgresql:5432/kratos?sslmode=require"
# with Hydra: HP="$(hex 24)"; p HYDRA_APP_PASSWORD="$HP" HYDRA_DSN="postgresql://hydra_app:${HP}@auth-postgresql:5432/hydra?sslmode=require"
unset KP HP
```

**`postgresqlSimple.appRoles` must be on for a fresh install** whose DSNs use `kratos_app` / `hydra_app`
(the minimal example has it; add the `hydra_app` entry when Hydra is on). initdb runs the script only on an
**empty** volume; without it, Postgres starts with the superuser alone and Kratos and Hydra fail to log in.

```sh

p COURIER_SMTP_CONNECTION_URI='smtps://<user>:<password>@<smtp-host>:465/'

# OPAL signing key pair (PEM, newlines as "_") and master token
D=$(mktemp -d); ssh-keygen -q -t rsa -b 4096 -m pem -N '' -f "$D/opal"
p OPAL_AUTH_PRIVATE_KEY="$(tr '\n' '_' < "$D/opal")" OPAL_AUTH_PUBLIC_KEY="$(cat "$D/opal.pub")" OPAL_AUTH_MASTER_TOKEN="$(hex 32)"
rm -rf "$D"
```

The two OPAL JWTs (`OPAL_CLIENT_JWT`, `OPAL_SERVER_JWT`) are signed by the running OPAL server, so they
cannot exist yet. Write random placeholders now so every pod can start (vault-env refuses to start a container
whose key is missing), and replace them in step 5:

```sh
p OPAL_CLIENT_JWT="$(hex 32)" OPAL_SERVER_JWT="$(hex 32)"
```

### 4. Install

Edit [`examples/minimal-values.yaml`](examples/minimal-values.yaml): replace every `example.com`, the Gateway
`parentRefs`, and the Vault address, role and path. `global.domain` alone does **not** rewrite the Kratos and
login-ui URLs. Then:

```sh
helm repo add w6dio https://charts.w6d.io
helm upgrade --install auth w6dio/auth -n auth --create-namespace -f minimal-values.yaml
```

What comes up:

- Postgres. An initdb script creates `kratos_app`, which owns database `kratos` (`postgresqlSimple.appRoles`).
- Redis.
- Kratos. Its automigrate init container creates the schema.
- jinbe. Its bootstrap init container runs (step 6).
- The OPAL server.

Both Ory migrations run as **init containers** (`kratos.kratos.automigration.type` and
`hydra.hydra.automigration.type` default to `initContainer`). Do not switch them to `job`: the job is a Helm
pre-install hook (Argo CD PreSync) that runs before Postgres exists, so a fresh install hangs.

The OPAL client stays **not Ready** (its client token is still a placeholder, so the OPAL server refuses it, and
OPA has no data). That is expected until step 5.

### 5. Mint the OPAL JWTs

The master token is read inside the OPAL server pod, and the JWTs go straight to Vault without being printed:

```sh
mint() { kubectl -n auth exec deploy/auth-opal-server -c opal-server -- python3 -c "
import json,urllib.request as u
e=dict(l.split('=',1) for l in open('/proc/1/environ').read().split(chr(0)) if '=' in l)
r=u.Request('http://127.0.0.1:7002/token',data=json.dumps({'type':'$1'}).encode(),
  headers={'Authorization':'Bearer '+e['OPAL_AUTH_MASTER_TOKEN'],'Content-Type':'application/json'})
print(json.load(u.urlopen(r))['token'],end='')"; }
CT=$(mint client) && DT=$(mint datasource) && [ ${#CT} -gt 100 ] && [ ${#DT} -gt 100 ] \
  && vault kv patch -mount=secret auth OPAL_CLIENT_JWT="$CT" OPAL_SERVER_JWT="$DT" >/dev/null
unset CT DT
kubectl -n auth rollout restart deploy/auth-opal-server deploy/auth-opal-client deploy/auth-jinbe
```

OPAL JWTs expire after **365 days**. Put the re-mint in a calendar: an expired JWT freezes OPA's data without
any error.

### 6. First-run bootstrap (automatic)

jinbe's `bootstrap` init container (`node dist/cli/bootstrap.js`) runs on every jinbe pod start. On the first
run (no Redis marker `rbac:bootstrap:state`), it:

1. seeds the access model from code: the 7 staff roles and their groups (`super_admins`, `staff-security`,
   `staff-auditors`, `staff-ops`, `staff-support`, `staff-developers`, `staff-viewers`), jinbe's org roles,
   and the generated route map (every jinbe route and the permission it needs);
2. writes the built-in gateway rules for the sign-in pages, the console and the API on your domains;
3. restores the RBAC bundle from `latest.json`, as `backup.restoreOnFirstInit` says (by default when the S3
   backup is on and a backup exists);
4. creates the **default super admin**: a Kratos identity `ADMIN_EMAIL` with password `ADMIN_PASSWORD`, email
   marked verified, in group `super_admins`. The password must be at least 16 characters with real entropy,
   or jinbe refuses to start (no weak default exists);
5. writes every group's "members must use 2FA" default (on for groups that can change anything), then the marker.

Later runs converge what jinbe owns and change nobody's membership. `ADMIN_*` is read on the first run only.
You can remove `ADMIN_PASSWORD` afterwards.

### 7. Sign in

```sh
kubectl -n auth get pods                       # all Running / Ready, the jinbe init container Completed
kubectl -n auth logs deploy/auth-jinbe -c bootstrap | tail -5   # 'Bootstrap complete', or 'marker present … converging' after the restart
```

The first-run lines (`First bootstrap run`, `Default admin identity created`) are in the log of the first jinbe pod,
before the step 5 restart.

Open `https://app.example.com`. You are sent to `https://auth.example.com/login`. Sign in with `ADMIN_EMAIL` and
`ADMIN_PASSWORD` (read it with `vault kv get -mount=secret -field=ADMIN_PASSWORD auth`, privately). `super_admins`
requires two-factor authentication, so you are asked to add an authenticator app or a security key. Then
kuma opens with every section.

Next steps:

- Add the 2 or 3 people who should be super admins.
- Put everyone else in the narrowest staff group.
- Turn on the [backup](#backup-and-restore).

## Secrets and Vault

**How references are resolved.** A value `vault:<path>#<KEY>` in an **env var** is replaced by vault-env (the
Bank-Vaults webhook) in the container's main process, at start, using the pod's service account and the
`vault.security.banzaicloud.io/vault-role` annotation. That has consequences:

- References in **files** (ConfigMaps) are never resolved. That is why Kratos web-hook secrets go through the
  generated `auth-kratos-webhook-env` Secret (env overrides), and Kratos/Hydra `secrets` through their Secrets.
- `kubectl exec … printenv` shows the raw reference, not the value. Only PID 1 has the value. Never print
  `/proc/1/environ`.
- A missing key stops the container (`VAULT_IGNORE_MISSING_SECRETS=false`): **write keys before the pods
  that read them roll out**.
- The pod needs the annotations (`global.vault` for jinbe, `<component>.podAnnotations` / `podMetadata` for the
  others), a service account bound to the role, and its token mounted (`automountServiceAccountToken: true`).

Every key the chart can read. Paths follow the minimal example: one path, `secret/data/auth`, and one role,
`auth`. Split them by component if you prefer. The "Pod (SA)" column is the default name for release `auth`.

| Key | Read by — pod (SA) | Values key | Generate | When |
|---|---|---|---|---|
| `ENCRYPTION_KEY` | jinbe (`auth-jinbe`) | `jinbe.env.ENCRYPTION_KEY` | `openssl rand -hex 32` (>= 32 chars) | always |
| `ADMIN_PASSWORD` | jinbe bootstrap (`auth-jinbe`) | `jinbe.env.ADMIN_PASSWORD` | `openssl rand -base64 24` (>= 16 chars, high entropy) | first run |
| `KRATOS_WEBHOOK_SECRET` | jinbe; Kratos via `auth-kratos-webhook-env` (`kratos`) | `jinbe.env.KRATOS_WEBHOOK_SECRET` **and** `global.audit.webhook.secret` (same value) | `openssl rand -hex 32` | always |
| `KRATOS_DSN` | Kratos, courier (`kratos`) | `kratos.deployment.extraEnv` / `kratos.statefulSet.extraEnv` `DSN` | `postgresql://kratos_app:<pw>@auth-postgresql:5432/kratos?sslmode=require` | always |
| `KRATOS_SECRETS_DEFAULT`, `KRATOS_SECRETS_COOKIE` | Kratos (`kratos`) | `kratos.kratos.config.secrets.default/cookie` | `openssl rand -hex 32` (>= 16 chars) | always |
| `KRATOS_SECRETS_CIPHER` | Kratos (`kratos`) | `kratos.kratos.config.secrets.cipher` | `openssl rand -hex 16` (**exactly 32 chars**) | always |
| `COURIER_SMTP_CONNECTION_URI` | Kratos, courier (`kratos`) | `kratos.*.extraEnv` | your SMTP URI | always |
| `PG_SUPERUSER_PASSWORD` | Postgres, app-roles Job (`default`) | `postgresqlSimple.auth.passwordVaultRef` | `openssl rand -hex 24` | bundled Postgres (read at initdb only) |
| `KRATOS_APP_PASSWORD`, `HYDRA_APP_PASSWORD` | Postgres initdb, app-roles Job (`default`) | `postgresqlSimple.appRoles.roles[].password` | `openssl rand -hex 24` (>= 16; URL-safe; **equal to the password inside `KRATOS_DSN` / `HYDRA_DSN`**) | `appRoles.enabled` (required with app-role DSNs) |
| `REDIS_PASSWORD` | Redis (`default`) via Secret `<redis.auth.existingSecret>`; jinbe | `redisAuthSecret.vaultRef`, `jinbe.env.REDIS_PASSWORD` | `openssl rand -hex 24` | `redis.auth.enabled` |
| `REDIS_BROADCAST_URL` | OPAL server (`default`) | `opal.server.broadcastUri` | `redis://:<REDIS_PASSWORD>@auth-redis-master:6379` | `uvicornWorkers > 1` |
| `OPAL_AUTH_PRIVATE_KEY`, `OPAL_AUTH_PUBLIC_KEY` | OPAL server; public key also on opal-client (`default`) | `opal.server.extraEnv`, `opal.client.extraEnv` | `ssh-keygen -t rsa -b 4096 -m pem`; private key with `\n` → `_` | always |
| `OPAL_AUTH_MASTER_TOKEN` | OPAL server (`default`) | `opal.server.extraEnv` | `openssl rand -hex 32` | always |
| `OPAL_CLIENT_JWT` | opal-client `OPAL_CLIENT_TOKEN`, OPAL server wait-for-data-source, jinbe `OPAL_CLIENT_TOKEN` | `opal.client.extraEnv`, `opal.server.waitForDataSource.bearerToken`, `jinbe.extraEnv` | minted, type `client` ([step 5](#5-mint-the-opal-jwts)), 365 d | always |
| `OPAL_SERVER_JWT` | jinbe `OPAL_SERVER_TOKEN` (`auth-jinbe`) | `jinbe.extraEnv` | minted, type `datasource`, 365 d | always |
| `OPA_ROOT_TOKEN` | opal-client `OPAL_POLICY_STORE_AUTH_TOKEN` (OPA inherits it); jinbe `OPA_TOKEN` | `opal.client.extraEnv`, `jinbe.extraEnv` | `openssl rand -hex 32` (>= 32, the `system.authz` rule) | always |
| `OPA_DECISION_TOKEN` | opal-client env (OPA's `system.authz`); opa-authz-proxy `OPA_TOKEN` (`default`) | `opal.client.extraEnv`, `opaAuthzProxy.opaToken` | `openssl rand -hex 32` (>= 32) | role headers |
| `KRATOS_ADMIN_TOKEN` | Kratos admin sidecar (`kratos`), jinbe, hydrator | `kratos.adminAuth.token`, `jinbe.extraEnv`, `hydrator.kratosAdminToken` | `openssl rand -hex 32` | `kratos.adminAuth.enabled` |
| `HYDRA_ADMIN_TOKEN` | Hydra admin sidecar (`auth-hydra`), Oathkeeper (`auth-oathkeeper`), jinbe, hydrator | `hydra.adminAuth.token`, `oathkeeper.adminAuth.tokenRef`, `jinbe.extraEnv`, `hydrator.hydraAdminToken` | `openssl rand -hex 32` | `hydra.adminAuth.enabled` |
| `HYDRA_DSN` | Hydra, automigrate Job (`auth-hydra`, `auth-hydra-job`) | `hydra.deployment.extraEnv` `DSN` | `postgresql://hydra_app:<pw>@auth-postgresql:5432/hydra?sslmode=require` | `hydra.enabled` |
| `HYDRA_SECRETS_SYSTEM`, `HYDRA_SECRETS_COOKIE` | Hydra (`auth-hydra`) | `hydra.hydra.config.secrets.system/cookie` | `openssl rand -hex 32` | `hydra.enabled` |
| `CAPTCHA_SECRET_KEY` (and the public `CAPTCHA_SITE_KEY`) | jinbe | `jinbe.captcha.secretKey` (default `vault:<jinbe.vaultPath>#CAPTCHA_SECRET_KEY`) | from Turnstile / hCaptcha / reCAPTCHA | `jinbe.captcha` |
| `AUDIT_HMAC_KEY` | jinbe | `jinbe.extraEnv` | `openssl rand -hex 32` (>= 32) | optional (pseudonymised IPs and sessions in audit) |
| `METRICS_TOKEN` | jinbe metrics port | `jinbe.metrics.token` | `openssl rand -hex 24` (>= 16) | optional |

Rules:

- `KRATOS_WEBHOOK_SECRET` in jinbe and in the Kratos hooks must be the **same value**.
- `OPA_ROOT_TOKEN` in opal-client and jinbe must be the same value, and so must `OPA_DECISION_TOKEN` in opal-client
  and the proxy. Rotate both sides in one release.
- The chart default for `global.audit.webhook.secret` and `jinbe.env.KRATOS_WEBHOOK_SECRET` is
  `vault:secret/data/auth#KRATOS_WEBHOOK_SECRET`. If your role cannot read that path, override both, or Kratos
  crash-loops.

## Backup and restore

jinbe exports the **RBAC bundle**: groups, members, roles, grants, sites' access and settings. It writes the
bundle to S3 on a schedule and on demand, and the bootstrap restores it on a first run. Kratos identities
and Hydra clients are **not** in the bundle: back up Postgres separately (`pg_dump`).

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"          # UTC; replicas dedupe through a Redis claim
  restoreOnFirstInit: auto       # first bootstrap run only: auto | "true" | "false" (below)
  s3: {bucket: <bucket>, prefix: <prefix>, region: <region>}
jinbe:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/<role>
```

kuma's Backup tab reads the same settings (`adminUi` gets `BACKUP_ENABLED`).

**Objects written**

| Key | When |
|---|---|
| `<prefix>/<timestamp>.json` and `<prefix>/latest.json` | Every scheduled or manual backup |
| `<prefix>-snapshots/rbac-pre-apply-<timestamp>.json` | Before an access-model move (`bootstrap --apply`): an exact copy of every `rbac:*` key, the rollback point |

**IAM policy for the IRSA role.** Note the second prefix, which is a **sibling** of `<prefix>/`, not inside it. A
policy that only allows `<prefix>/*` makes `--apply` fail with `AccessDenied` on the snapshot:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": "s3:ListBucket", "Resource": "arn:aws:s3:::<bucket>",
     "Condition": {"StringLike": {"s3:prefix": ["<prefix>/*", "<prefix>-snapshots/*"]}}},
    {"Effect": "Allow", "Action": ["s3:GetObject", "s3:PutObject"],
     "Resource": ["arn:aws:s3:::<bucket>/<prefix>/*", "arn:aws:s3:::<bucket>/<prefix>-snapshots/*"]}
  ]
}
```

Trust: `system:serviceaccount:<namespace>:auth-jinbe` (the jinbe SA), audience `sts.amazonaws.com`. Add
`kms:Encrypt`/`kms:Decrypt`/`kms:GenerateDataKey` if the bucket uses SSE-KMS. The bundle contains email
addresses: keep the bucket private, versioned and encrypted, with a lifecycle rule.

**Restore on first init** (`backup.restoreOnFirstInit`, env `BACKUP_RESTORE_ON_FIRST_INIT`, on the jinbe pod and
its bootstrap): what the **first** bootstrap run (no marker in Redis) does with `<prefix>/latest.json`:

| Value | Behaviour | Use for |
|---|---|---|
| `auto` (default) | Restore when backup is on and a `latest.json` exists; otherwise, or if the import fails, keep the freshly seeded model | Normal installs |
| `"false"` | Never restore (logs `first init: restore skipped`) | A deliberate blank rebuild, without the old access model |
| `"true"` | Restore, or fail the bootstrap with **exit 9** (backup off, no `latest.json`, or a failed import). No marker is written, so jinbe retries on the next start | Disaster recovery: never come up empty by accident |

Later runs ignore it. Quote `"true"` / `"false"` or not, both render the same. It needs a jinbe image that reads
`BACKUP_RESTORE_ON_FIRST_INIT`; older images ignore it and behave as `auto`.

**Operate**

| Action | How |
|---|---|
| Back up now | kuma → Backup → "Back up now", or `POST /api/admin/rbac/bundle/backups/now` (`policy.bundle:write`) |
| List | `GET /api/admin/rbac/bundle/backups` (`policy.bundle:read`) |
| Restore a backup | `POST /api/admin/rbac/bundle/backups/restore` with `{"key": "<prefix>/<timestamp>.json"}` (`policy.bundle:write`). Audited; OPA sees the result within seconds. |
| Rebuild from zero | A first run (empty Redis, no bootstrap marker) seeds the model, then follows `backup.restoreOnFirstInit`. |
| Roll back an access-model move | `node dist/cli/bootstrap.js --restore-snapshot <prefix>-snapshots/<name>.json`, then redeploy the previous release ([Upgrading](#upgrading)). |

## Authorization model

Everything is explicit: no wildcards, no inheritance. The same data drives jinbe's checks and OPA's gateway
decisions, so they cannot disagree.

**Permissions and apps.** A permission is `resource:verb` (for example `users:recovery` or `sites:apply`) inside an
**app**: jinbe itself, or a published site. Each route of an app maps to one permission (jinbe's route map is
generated from its OpenAPI). OPA allows a request when the caller holds that permission in that app, in the right
scope (platform, or the organisation in the path).

**Built-in staff roles** (code-defined, rewritten by every bootstrap, never edited at runtime). Each one is bound
by one group:

| Group | Role | In short |
|---|---|---|
| `super_admins` | super_admin | Every platform permission (generated from the catalogue). Keep it to 2 or 3 people. |
| `staff-security` | security | Incident response: sessions, disable, reset 2FA, recertification, audit export |
| `staff-auditors` | auditor | People, access and audit evidence, read-only |
| `staff-ops` | ops | Publish sites, zones and the gateway, approve requests |
| `staff-support` | support | Find people, fix sign-in, manage organisation members |
| `staff-developers` | developer | Plug and change sites, import OpenAPI |
| `staff-viewers` | viewer | Sites, groups, organisations and counts; no personal data |

super_admin acts in every organisation. support (members), auditor and security (read) act in organisations they
do not belong to. The other roles do not.

**Organisation roles.** jinbe defines `owner`, `member_manager`, `key_manager`, `auditor` and `viewer`. They are
assigned per person per organisation (`jinbe:owner`), and they act only inside that organisation.

**Sites' own roles.** A published site declares its app's roles and permissions. Grant them through a group
(`{<app>: [<role>]}`), an organisation role, or a direct grant.

**Per-person grants.** A role or a permission held without a group, in a platform or organisation scope
(`/api/admin/users/:id/grants`, `/api/organizations/:org/users/:id/grants`). Use them for exceptions, and
review them in kuma.

**The holding rule.** Nobody grants what they do not hold. Every assignment, group join and direct grant is
decided by the policy (`rbac.delegation`), over the same data the gateway uses. A refusal returns 403 with each
reason (`missing_permissions`, `grantee_not_member`, …) and who could grant it instead.

**2FA per group.** Each group has one "Members must use 2FA" switch (kuma → group; only a super admin changes
it). When it is on:

- the group's members need an `aal2` session on every route that carries a permission;
- nobody joins the group before enrolling a second factor.

By default the switch is on for any group that can change something, and off for read-only groups,
`staff-viewers` and `staff-auditors`.

**Role headers (opt-in).** A site gate can forward the caller's `X-User-Groups`, `X-User-Roles` and
`X-User-Permissions` for the site's app. Every link must be in place, or the headers stay blank or the gate
answers 403:

1. the gate uses the policy authorizer and has `passRoles: true` (kuma → site → gate);
2. jinbe has `SITES_ROLE_HEADERS: "true"` (`jinbe.extraEnv`). Optionally set `SITES_AUTHZ_DECISION_URL`; the default derives `/decision` from the gateway's `/allow` remote;
3. the proxy presents a token: `opaAuthzProxy.opaToken` (`OPA_DECISION_TOKEN`);
4. OPA accepts that token for `POST /v1/data/rbac/decision`: the `system.authz` rule in
   `opal.client.opaStartupData`, plus `OPA_DECISION_TOKEN` in `opal.client.extraEnv` (see the minimal example).

## GitOps with Argo CD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: auth, namespace: argocd}
spec:
  project: default
  destination: {server: https://kubernetes.default.svc, namespace: auth}
  sources:
    - repoURL: https://charts.w6d.io           # or https://github.com/w6d-io/charts.git, path charts/auth
      chart: auth
      targetRevision: <version>
      helm:
        releaseName: auth
        valueFiles: [$values/auth/values.yaml]
    - {repoURL: https://git.example.com/infra/k8s.git, targetRevision: HEAD, ref: values}
  # Fields site-operator writes at runtime; without these, Argo and the operator fight
  ignoreDifferences:
    - {group: apps, kind: Deployment, name: auth-oathkeeper, managedFieldsManagers: [site-operator]}
    - {group: "", kind: ConfigMap, name: auth-site-operator-zones, managedFieldsManagers: [site-operator]}
  syncPolicy:
    syncOptions: [CreateNamespace=true, ServerSideApply=true, RespectIgnoreDifferences=true]
    # Labels the namespace needs before anything is created in it: Argo applies them when it creates
    # (or recreates) the namespace
    managedNamespaceMetadata:
      labels:
        # the label your Gateway's allowedListeners selects (site zones attach a ListenerSet to it)
        <gateway-listener-label>: "true"
        pod-security.kubernetes.io/enforce: restricted
```

- **Namespace labels.** When site-operator zones attach a `ListenerSet` to a shared Gateway whose
  `allowedListeners` admits only labelled namespaces (`namespaces: {from: Selector, selector: {matchLabels: …}}`),
  a namespace without that label has every platform HTTPRoute (console, API, sign-in, Hydra) unattached.
  Argo then waits on their health forever and never reaches the later sync waves (jinbe is never created).
  `managedNamespaceMetadata` puts the label on a namespace Argo creates, including after a delete.

- **`RespectIgnoreDifferences=true`** is required with site-operator. Otherwise a sync points Oathkeeper back at
  the seed config map and drops every site rule.
- **`siteOperator.admission.ruleWriters`** must name your Argo CD controller,
  `system:serviceaccount:<argo namespace>:argocd-application-controller`. The rules admission policy refuses
  every other writer, including Argo applying the chart's `platform-ready` Rule. There is no default; NOTES warn when it is empty.
- **Site policies carry their parameters inline.** The site-operator ValidatingAdmissionPolicies do not read a
  params ConfigMap: the chart writes the values into their CEL. That covers the operator and writer identities,
  the reserved hosts, the upstream regexes, the gateway Service and Gateways, and the issuer route. It also covers
  the **Zone domains and Zone TLS Secrets, taken from `sites.zones`**. So list every Zone there, with its `tls`
  as the Zone has it (`mode: issuer` → Secret `zone-<name>-tls`; `mode: secret` → `secretName`), even with
  `siteOperator.installZones: false`.

  Why: the API server's param informer is unreliable for a namespace that was deleted and recreated. Bindings
  kept answering "no params found" although the ConfigMap existed, and later evaluated with a **stale copy** of it
  (a Zone added after the rebuild was refused). Annotating the ConfigMap, and recreating the bindings and the
  policies, did not refresh it.

  `siteOperator.admission.zoneParams: true` re-adds the operator's Zone mirror (`<release>-site-operator-zones`)
  as an extra source, for Zones created at runtime from kuma. It is read with `parameterNotFoundAction: Allow`
  (a namespace delete cannot deadlock), so it inherits that informer risk.
- **Deleting the app or the namespace.** The policy `<namespace>-site-operator-params` refuses deleting the
  `<release>-site-operator-policy` and `-zones` ConfigMaps unless:
  - the namespace is being deleted;
  - the caller is in `system:masters` (a `cluster-admin` binding is not enough);
  - or the caller is listed in `siteOperator.admission.paramDeleters`.

  Add your Argo CD controller there if you delete the app but keep the namespace.
- **`clusterResources.annotations`** applies to every cluster-scoped object (ValidatingAdmissionPolicies,
  ClusterRoles, ClusterRoleBindings). Use `argocd.argoproj.io/sync-options: Prune=false,Delete=false` so deleting
  the app keeps them.
- **OPAL restart on a jinbe release.** The OPAL server reads jinbe's data-source entry list only when it starts.
  Set `global.jinbeRevision` to the same value as `jinbe.image.tag`: its checksum rolls the OPAL server in the same sync.
- **Pin images.** Use a commit tag (`sha-<short>`) or `tag@sha256:<digest>`, with `pullPolicy: IfNotPresent`.
  A moving tag (`develop`, `latest`) with `Always` changes code on any pod restart.
- **Hooks.** The jinbe bootstrap runs as an init container: no hook ordering is needed. The Postgres app-roles Job
  (`post-install,post-upgrade`) runs as a PostSync hook. Helm test pods are ignored by Argo.
- Never sync without reading `argocd app diff` first.

## Upgrading

### Server-side apply (Argo CD `ServerSideApply=true`)

Server-side apply removes only the fields its own manager owned. Two consequences when a release takes over
objects that were also edited by hand (`kubectl set env`, `kubectl patch`):

- **An env var that switches between `value` and `valueFrom` fails the apply.** The merged object carries both,
  and the API server rejects it (`valueFrom: may not be specified when value is not empty`). Examples:
  - the Redis password (`value` → `secretKeyRef` of `redisAuthSecret`);
  - `OPA_DECISION_TOKEN` on opal-client when it moves from a Secret to a vault reference.

  Apply those objects once with replace (`argocd app sync --resource <group>:<kind>:<name> --replace`, or the
  `Replace=true` sync option on the object). For a StatefulSet, replace works only while
  `volumeClaimTemplates`, `selector` and `serviceName` are unchanged.
- **Hand-added fields survive a sync** (env vars, annotations), so "Synced" does not mean "equal to the chart".
  After the first sync, replace each object that still lists foreign managers in `metadata.managedFields`
  once. From then on, the release is the only writer.

### Access-model releases (bootstrap schema)

The bootstrap marker carries a schema version (today **8**). A jinbe release with a higher schema version **wipes
and reseeds** the stored access model from code and the applied sites. It does that only with a reviewed plan's
hash; otherwise the bootstrap exits **6** and changes nothing (the jinbe pod stays in `Init:Error`). The flow:

1. **Plan (read-only).** Run the new image's `node dist/cli/bootstrap.js --plan --out /tmp/plan --opa` with
   jinbe's env, service account and Vault annotations. Use a one-off Job copied from the jinbe pod spec, with
   other labels so the Service never selects it. It writes:
   - `plan.md` and `plan.json`: today's state, every rule after the move, each person's gains and losses, the
     orphans and the migration map;
   - the `planHash`.
2. **Review** `plan.md` with the owner. Losses for real people are the point of the review.
3. **Apply.** Either set `JINBE_RBAC_APPLY_EXPECT: <planHash>` in `jinbe.extraEnv` for the release's own bootstrap,
   or run a one-off Job with `bootstrap.js --apply --expect <planHash>`. The apply:
   - refuses if the live state no longer gives that hash (exit 6: plan again);
   - takes a **mandatory snapshot** to `<prefix>-snapshots/` and refuses (exit 8) unless it outlives the pod (S3
     backup on, or `JINBE_SNAPSHOT_DIR` on a volume with `JINBE_SNAPSHOT_DIR_DURABLE=true`).
     `--allow-ephemeral-snapshot` is the only, logged, override.
4. **Verify.** Sign in as a super admin and as one person per staff group. Check OPA (see Troubleshooting).
5. **Roll back** if needed: `bootstrap.js --restore-snapshot <prefix>-snapshots/rbac-pre-apply-<ts>.json`, then
   redeploy the previous release.

Bootstrap exit codes:

| Code | Meaning |
|---|---|
| 0 | Success, no-op, or the lock is held by another runner |
| 1 | Invalid environment, or required first-run config missing |
| 2 | Redis or Kratos not reachable in time |
| 3 | The bootstrap failed (after the env and dependency checks) |
| 4 | Schema downgrade (an older jinbe on a newer store) |
| 5 | Corrupt marker |
| 6 | Old-model store, and no reviewed plan approves the move |
| 7 | Break-glass refused |
| 8 | Apply refused: the snapshot would not outlive the pod |
| 9 | First init with `backup.restoreOnFirstInit: "true"` and no restore: backup off, no `latest.json`, or a failed import. No marker is written, so the next run tries again. |

## Values reference

The keys most installs touch, grouped by component. Everything else is documented inline in
[`values.yaml`](values.yaml).

| Key | Default | Notes |
|---|---|---|
| `global.domain` / `authDomain` / `appDomain` | `example.com` / `auth.<domain>` / `app.<domain>` | Drive jinbe, kuma and the gateway hosts. Kratos and login-ui URLs are set separately. |
| `global.vault.{enabled,address,role,envFromPath}` | off | vault-env annotations on jinbe (Deployment and bootstrap). |
| `global.audit.webhook.secret` | `vault:secret/data/auth#KRATOS_WEBHOOK_SECRET` | Kratos → jinbe hook secret. |
| `global.jinbeRevision` | `""` | Rolls the OPAL server when jinbe changes. |
| `kratos.deployment.extraEnv`, `kratos.statefulSet.extraEnv` | bundled DSN | `DSN`, `COURIER_SMTP_*` as vault refs. |
| `kratos.kratos.config.*` | example.com URLs | `serve.public.base_url`, `cors`, `session.cookie.domain`, `selfservice.*` URLs, `secrets`. |
| `kratos.adminAuth.{enabled,token}` | off | Token sidecar in front of the Kratos admin API. |
| `oathkeeper.edge.httpRoute.{enabled,parentRefs,hosts,cors,requestTimeout}` | off | Gateway API exposure of the platform hosts. |
| `oathkeeper.ingress.proxy.*` | Ingress on | nginx exposure (set `enabled: false` with the HTTPRoute). |
| `oathkeeper.rules.source` | `legacy` | `dual` with Sites (adds the maester sidecar). |
| `oathkeeper.adminAuth.tokenRef` | `""` | Hydra admin token for introspection (vault ref). |
| `hydra.enabled`, `hydra.edge.httpRoute`, `hydra.adminAuth`, `hydra.hydra.config.urls.self.issuer` | off | Issuer must end with `/`. |
| `kratos.kratos.automigration.type`, `hydra.hydra.automigration.type` | `initContainer` | Keep it: `job` is a pre-install hook that hangs a fresh install. |
| `jinbe.image.tag`, `jinbe.env.*`, `jinbe.extraEnv` | chart appVersion | `env`: the keys the chart knows. `extraEnv`: anything else (`OPAL_*`, `OPA_TOKEN`, `SITES_ROLE_HEADERS`, `JINBE_RBAC_APPLY_EXPECT`, admin tokens). |
| `jinbe.serviceAccount.annotations` | `{}` | IRSA role for backup. |
| `jinbe.captcha.*`, `jinbe.signInGate.*` | off | Bot check and sign-in code limits. |
| `jinbe.observability.*` | off | Loki, Grafana (audit tab, logs). |
| `adminUi.image.tag`, `kratosLoginUi.image.tag` | pinned releases | kuma and login-ui. |
| `kratosLoginUi.{kratos.browserUrl,redirects.*,consoleUrl,branding.*}` | example.com | login-ui URLs and branding. |
| `opal.server.{policyRepoUrl,policyRepoMainBranch,extraEnv,podAnnotations,waitForDataSource.bearerToken}` | w6d policies, `main` | |
| `opal.client.{extraEnv,podAnnotations,opaStartupData}` | | OPA token auth and `system.authz`. |
| `opaAuthzProxy.{image.tag,opaToken,opaTokenSecretRef,podAnnotations,automountServiceAccountToken}` | `v0.4.0`, no token | `v0.6.0` or later is needed for `OPA_TOKEN`. |
| `redis.auth.*`, `redisAuthSecret.vaultRef` | auth off | See the minimal example for the vault-env pod settings. |
| `postgresqlSimple.{auth.passwordVaultRef,tls.enabled,hba,appRoles}` | | App roles: initdb on an empty volume plus a hook Job. **Required** on a fresh install with app-role DSNs. |
| `postgresqlSimple.podSecurityContext.fsGroup` | `999` (`OnRootMismatch`) | Lets postgres create PGDATA on a root-owned fresh volume. |
| `backup.{enabled,schedule,s3.*}` | off | |
| `mcp.{enabled,host,image.tag,readOnly,httpRoute}` | off | Needs an OAuth issuer (Hydra, or `mcp.authorizationServer`); jinbe verifies auth-mcp's service-account token with TokenReview (`mcp.tokenReviewBinding`). |
| `sites.{enabled,zones,zoneRbac,reservedHosts,upstreamAllow,...}` | off | jinbe's site publishing. `zones` must list **every** Zone (with `tls`): the site policies take the Zone domains and TLS Secrets from it. |
| `siteOperator.admission.zoneParams` | `false` | Also read the operator's Zone mirror ConfigMap (Zones created at runtime). |
| `siteOperator.{enabled,image.tag,gatewayApi,admission.ruleWriters,admission.paramDeleters,installCRDs,installZones}` | off | |
| `gatekit.{enabled,image.tag}` | off | |
| `clusterResources.annotations` | `{}` | On every cluster-scoped object. |
| `observability.serviceMonitors.*` | off | |

### Branding (kuma and login-ui)

Both images read their branding at runtime, through env vars:

```yaml
adminUi:
  extraEnv:
    APP_NAME: Example                                   # tab title "<APP_NAME> — Access console"
    LOGO_URL: https://cdn.example.com/logo.svg          # full logo (wordmark)
    LOGO_DARK_URL: https://cdn.example.com/logo-dark.svg
    LOGO_SMALL_URL: https://cdn.example.com/icon.svg    # square logo; also the tab icon by default
    FAVICON_URL: https://cdn.example.com/favicon.png    # when it is not the small logo
    MCP_SERVER_URL: https://mcp.example.com/mcp         # shown on Connections & keys (with mcp.enabled)
    MCP_SERVER_NAME: example                            # name in MCP client snippets (lowercase, digits, dashes)
kratosLoginUi:
  branding:
    appName: Example                                    # NEXT_PUBLIC_APP_NAME
  extraEnv:
    LOGO_URL: https://cdn.example.com/logo.svg
    LOGO_DARK_URL: https://cdn.example.com/logo-dark.svg
    LOGO_SMALL_URL: https://cdn.example.com/icon.svg
    LOGO_SHOWS_NAME: "false"                            # the logo has no product name: show the name beside the small logo
    FAVICON_URL: https://cdn.example.com/favicon.png
```

URLs must be `https://…` or a path on the same origin. kuma's read-only root means the chart, not the image,
substitutes these into `index.html`: its `render-html` init container (`templates/admin-ui/deployment.yaml`) runs
`envsubst` with a whitelist that must name every runtime var the image substitutes. A var missing from that
list is served literally (`${LOGO_URL}` in the page). When you bump kuma, compare the two lists, ideally in CI:

```sh
img=$(git show <kuma-ref>:Dockerfile | grep -o "envsubst '[^']*'" | grep -o '\${[A-Z_]*}' | sort -u)
chart=$(grep -o "envsubst '[^']*'" charts/auth/templates/admin-ui/deployment.yaml | grep -o '\${[A-Z_]*}' | sort -u)
diff <(echo "$img") <(echo "$chart") && echo "whitelists match"
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Apps behind an **enrich** gate (hydrator + header mutators) receive no cookies, or no request headers at all | A hydrator that replies with only `{subject, extra}`: Oathkeeper **replaces** its session with the hydrator's reply, so `match_context` is lost, and later mutators (the Cookie strip reads `.MatchContext.Header`) see no request headers | The hydrator must echo the whole session it receives, with only `extra` changed (the bundled hydrator does, since charts e65a6ee). When retesting after a fix, change the cookie value: the hydrator mutator caches replies for 60 s, keyed on the full session JSON, so an identical request can get the stale reply. |
| kuma shows `${LOGO_URL}` (or another `${…}`) literally, or a branding or MCP value is ignored | The chart's read-only render (`render-html` init container) lacks that var in its `envsubst` whitelist | Add the var to the whitelist in `templates/admin-ui/deployment.yaml`, to match the kuma Dockerfile's list ([Branding](#branding-kuma-and-login-ui)). Fixed for `MCP_SERVER_URL`, `MCP_SERVER_NAME`, `LOGO_*`, `FAVICON_URL` and `APP_NAME` in charts 1a61eef / 9173954. |
| A zone reports `ListenerSet attachment from namespace <ns> not allowed`; the console, API, sign-in and Hydra routes stay unhealthy; the Argo sync waits forever and later waves (jinbe) are never created | The namespace lacks the label the Gateway's `allowedListeners` selects (typical after the namespace was recreated) | Add `syncPolicy.managedNamespaceMetadata.labels` with that label to the Application ([GitOps](#gitops-with-argo-cd)), or label the namespace. Then terminate the running sync and sync again (next row). |
| An Argo sync keeps "waiting for healthy state" after an admission policy (or any error) refused some resources | A sync operation does not retry resources that failed; it waits for health with the failures recorded | Fix the cause, then **terminate the operation** (`argocd app terminate-op <app>`) and sync again. |
| Kratos fails its config schema: `doesn't validate with #/definitions/selfServiceAfterRegistration` (or a similar `#/definitions/…`) | A key set to `null` in values inside `kratos.kratos.config` (e.g. `selfservice.flows.registration.after.password: null`): Helm passes the null through to the subchart, and it is rendered literally | Never null keys inside the Kratos or Hydra config. Override the parent value with the full list or map you want instead. |
| Site policy bindings answer `no params found` although the params ConfigMap exists, or a Site host under an existing Zone is refused (`every site host must be one DNS label under a Zone domain`) although `<release>-site-operator-zones` lists the domain, after the namespace was recreated | Charts before C9 read params ConfigMaps, and the API server's param informer for a recreated namespace serves none, or a stale copy. Annotating the ConfigMap or recreating the bindings and policies does not refresh it | Upgrade the chart: the policies carry their parameters inline. Add the Zone to `sites.zones` (with `tls`). |
| The operator's zone ListenerSet or host Ingress is refused: `a zone ListenerSet uses a Zone TLS Secret` / `… uses a Zone TLS Secret` | The Zone's `tls` is missing from its `sites.zones` entry, so the policy does not know its Secret | Set `tls` on the entry as on the Zone (e.g. `{mode: issuer, issuer: <issuer>}` → `zone-<name>-tls`). |
| A jinbe release with new data paths (a new feed) does not reach OPA: rules fail or decisions miss data; the OPAL client logs no error | The OPAL server read jinbe's entry list at start and keeps the old one | `kubectl rollout restart deploy/auth-opal-server`, then `deploy/auth-opal-client`. Prevent it with `global.jinbeRevision`. |
| Site gates with role headers answer **403/502**; plain gates work | OPA's `system.authz` refuses `POST /v1/data/rbac/decision`: rule missing, `OPA_DECISION_TOKEN` unset or under 32 chars on opal-client, or the proxy token differs | Check [role headers](#authorization-model) steps 3 and 4. Both sides must read the same Vault key. |
| jinbe stuck in `Init:Error`, bootstrap log `exit 6` / `MigrationNotApprovedError` | The store is the previous model's schema | Plan, review, apply ([Upgrading](#access-model-releases-bootstrap-schema)). |
| `--apply` fails with `AccessDenied` writing `<prefix>-snapshots/...` | The IAM policy only covers `<prefix>/*` | Add `<prefix>-snapshots/*` ([Backup](#backup-and-restore)). |
| `--apply` exits 8 | No durable snapshot target | Turn on the S3 backup, or a durable `JINBE_SNAPSHOT_DIR`. |
| A pod fails at start with a vault-env error that a key or path was not found or not permitted | Key missing in Vault, wrong path, or the SA not bound to the role | Write the key with `vault kv patch`, then fix the role binding (`bound_service_account_names`). Then the container starts on its next restart. |
| Kratos crash-loops after a values change, mentioning the webhook secret | `global.audit.webhook.secret` (default `secret/data/auth`) not readable by your role | Override it and `jinbe.env.KRATOS_WEBHOOK_SECRET` together. |
| Kratos → jinbe audit/guard hooks get 401 | The Kratos side sends the literal `vault:` string (a reference in the ConfigMap, not in env) | Keep `kratos.deployment.environmentSecretsName` (`auth-kratos-webhook-env`). Do not put secrets in hook config directly. |
| Everyone gets 403 right after an install or restart | OPA has no data yet: the OPAL client is not Ready | Wait for the startup probe (`requireBindings`). Check the OPAL JWTs exist and have not expired. |
| Large site drafts, OpenAPI imports or MCP tool calls get **403/413** at the edge | A WAF (Coraza/ModSecurity) in front blocks or cannot inspect bodies past its limit (often 128 KiB) | Exclude those paths from body inspection, or raise the limit for the console, API and MCP hosts. |
| Postgres crash-loops on a fresh volume: `mkdir: cannot create directory '/var/lib/postgresql/data/pgdata': Permission denied` | The new volume is root-owned and the pod runs as uid 999 without `fsGroup` (charts before C8) | Set `postgresqlSimple.podSecurityContext.fsGroup: 999` and `fsGroupChangePolicy: OnRootMismatch` (the default now). Then **delete the crash-looping pod**: a StatefulSet does not roll a pod that never became Ready, so the fixed spec waits forever otherwise. |
| Kratos or Hydra cannot log in (`password authentication failed for user "kratos_app"` / `role … does not exist`); the Postgres log shows `ignoring /docker-entrypoint-initdb.d/*` | initdb ran without the app-roles script: `postgresqlSimple.appRoles` was off on the first start | Enable `appRoles` with the roles your DSNs use. Then either recreate the **empty** volume (initdb runs only on an empty PGDATA: delete the StatefulSet's PVC and pod; this loses the data), or let the app-roles Job create the roles. That Job is a **PostSync** hook (Helm post-install/upgrade), so it never runs while Kratos or Hydra crash-loop in their migration init container: run it by hand (`helm template … -s templates/postgresql-simple/app-roles-job.yaml` and apply it), or scale Kratos/Hydra to 0 until it has run. |
| A fresh install or Argo sync hangs on a `*-automigrate` Job (PreSync) | `automigration.type: job`: the hook runs before Postgres exists | Set `kratos.kratos.automigration.type` and `hydra.hydra.automigration.type` to `initContainer` (the default). Delete the stuck Job. |
| The namespace stays **Terminating**; its conditions show `ValidatingAdmissionPolicy '<ns>-site-operator-…' … denied request: … no params found` | Charts before C8 bound the site policies with `parameterNotFoundAction: Deny`. The namespace delete removes the params ConfigMaps first, then every remaining delete is refused. | Upgrade the chart. To unblock now: `kubectl delete validatingadmissionpolicybindings -l app.kubernetes.io/instance=<release>` (named `<ns>-site-operator-*`); a sync recreates them. |
| The namespace stays **Terminating** on `rules.oathkeeper.ory.sh` objects | The Rule CRs keep the `finalizer.oathkeeper.ory.sh` finalizer, but their maester sidecar is gone with the Oathkeeper pod | `kubectl -n <ns> get rules.oathkeeper.ory.sh -o name \| xargs -I{} kubectl -n <ns> patch {} --type=merge -p '{"metadata":{"finalizers":null}}'`, only for a namespace you are deleting. |
| Deleting `<release>-site-operator-policy` / `-zones` is refused by `<ns>-site-operator-params` | The guard: those ConfigMaps feed the site policies | Expected. Delete the namespace, or add the caller to `siteOperator.admission.paramDeleters`. |
| `helm template` fails with `jinbe.env.ENCRYPTION_KEY is required` | Bare defaults | Start from `examples/minimal-values.yaml`. |
| The first sign-in is asked for a second factor | `super_admins` requires 2FA (the default for write-capable groups) | Enrol an authenticator or a security key. That is expected. |

**Checks**

```sh
kubectl -n auth logs deploy/auth-jinbe -c bootstrap | tail -20            # bootstrap outcome
kubectl -n auth logs deploy/auth-opal-client | grep -iE '401|403|error' | tail
kubectl -n auth get httproute,pods                                       # routes Accepted, pods Ready
curl -s -o /dev/null -w '%{http_code}\n' https://auth.example.com/login   # 200
```
