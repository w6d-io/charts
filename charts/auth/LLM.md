# LLM.md: operating the auth chart as an AI assistant

You are helping a person install or operate the `auth` chart: Kratos, Oathkeeper, OPAL/OPA, opa-authz-proxy,
jinbe, kuma, login-ui, Redis and Postgres, plus optional Hydra, auth-mcp, site-operator and gatekit. This file
gives you the facts, the order, the guard rails and the checks. The human documentation is [README.md](README.md),
linked per section below. Prefer reading the chart (`values.yaml`, `templates/`) over guessing.

## Non-negotiable rules

1. **Never print a secret.** No `vault kv get` without `-field … | wc -c`, no `cat /proc/1/environ`, no
   `kubectl get secret -o yaml`, no echoing generated values. Generate secrets inside the command that stores them.
   `kubectl exec … printenv` is safe: it shows the `vault:` reference, not the value.
2. **`vault kv patch`, never `vault kv put`**, on a path that already exists. `put` replaces the whole path and
   silently deletes every other key, and the pods that read them stop at their next start.
3. **Never sync or upgrade without a diff first**: `helm diff upgrade` or `argocd app diff`. Read it and show it.
   Never `argocd app sync` a whole app on the operator's behalf without an explicit go.
4. **Write Vault keys before the pods that read them roll out.** vault-env stops a container whose key is missing.
5. **Never run `bootstrap.js --apply`** without a plan the operator has reviewed, and its exact `planHash`.
6. Ask before any cluster-scoped change: CRDs, ValidatingAdmissionPolicies and their bindings, ClusterRoles, Zones,
   AppProject. Never remove finalizers or admission bindings outside a namespace that is being deleted.
7. Never put a `vault:` reference where only a file reads it (a ConfigMap, the Kratos config file), except through
   the chart's env mechanisms (`auth-kratos-webhook-env`, `secrets` lists). A file never gets the reference resolved.
8. Never disable the OPA token auth (`OPAL_INLINE_OPA_CONFIG` authentication), the `system.authz` rule, or the
   NetworkPolicies to "make it work". Fix the cause instead.
9. Never set a key to `null` inside `kratos.kratos.config` or `hydra.hydra.config` to "remove" it: Helm passes the
   null to the subchart, which renders it literally, and Kratos/Hydra fail their schema. Override the parent list or
   map with exactly what you want.
10. A fresh install or rebuild goes in this order: Vault keys (app-role passwords and `OPA_DECISION_TOKEN` included)
   → namespace labels (Gateway `allowedListeners` label, Pod Security) → install/sync → read the first jinbe
   pod's bootstrap log.

## Facts you must not get wrong

- **Secrets** resolve in the pod's **main process at start** (Bank-Vaults vault-env). A pod needs:
  - the `vault.security.banzaicloud.io/vault-addr` and `vault-role` annotations;
  - a service account bound to the role;
  - `automountServiceAccountToken: true`.

  jinbe gets the annotations from `global.vault`. Every other component has its own `podAnnotations` /
  `podMetadata`. The full key table: [README › Secrets and Vault](README.md#secrets-and-vault).
- **Paired values must match:**
  - `KRATOS_WEBHOOK_SECRET`, in `jinbe.env` and `global.audit.webhook.secret`;
  - `OPA_ROOT_TOKEN`, in opal-client `OPAL_POLICY_STORE_AUTH_TOKEN` and jinbe `OPA_TOKEN`;
  - `OPA_DECISION_TOKEN`, in opal-client env and `opaAuthzProxy.opaToken`;
  - `OPAL_CLIENT_JWT`, in opal-client, jinbe and `waitForDataSource.bearerToken`.
- **Length rules:**
  - `ENCRYPTION_KEY` >= 32;
  - `ADMIN_PASSWORD` >= 16, with real entropy (jinbe refuses to start otherwise; there is no default);
  - Kratos `cipher` exactly 32;
  - Kratos `default`/`cookie` >= 16;
  - OPA tokens >= 32;
  - Postgres app-role passwords >= 16.
- **`global.domain` does not rewrite Kratos or login-ui URLs.** Set `kratos.kratos.config.serve`, `session.cookie.domain`,
  `selfservice.*` URLs and `kratosLoginUi.{kratos.browserUrl,redirects.*,consoleUrl}` explicitly. See
  `examples/minimal-values.yaml`.
- **OPAL JWTs** are minted by the running OPAL server (`POST /token` with the master token, `type` `client` and
  `datasource`). They last **365 days**, and an expired one freezes OPA's data without an error.
- **The OPAL server reads jinbe's data-source list only on start.** After a jinbe release, restart the OPAL server
  and then the client, or set `global.jinbeRevision` = `jinbe.image.tag`.
- **Bootstrap**: init container `bootstrap` in the jinbe pod, Redis marker `rbac:bootstrap:state`, schema version 8.
  - First run: seeds the model from code, writes the gateway rules, restores `latest.json` if backup is on, creates
    the `ADMIN_EMAIL` super admin.
  - An older-schema store needs a reviewed plan. Otherwise it exits **6**.
  - Exit codes: [README › Upgrading](README.md#access-model-releases-bootstrap-schema).
- **Backup** writes `<prefix>/<ts>.json`, `<prefix>/latest.json`, and the apply snapshot to the **sibling**
  `<prefix>-snapshots/`. IAM must allow both prefixes.
- **Staff groups** (code-defined, never edited): `super_admins`, `staff-security`, `staff-auditors`, `staff-ops`,
  `staff-support`, `staff-developers`, `staff-viewers`. Nobody grants what they do not hold (the holding rule). The
  2FA switch is per group.
- **Role headers** need four links: gate `passRoles` (policy authorizer), jinbe `SITES_ROLE_HEADERS=true`, proxy
  `opaToken`, and OPA's `system.authz` decision rule plus `OPA_DECISION_TOKEN` on opal-client.
- **Postgres on a fresh volume** needs `fsGroup: 999` (`OnRootMismatch`, the chart default), and
  `postgresqlSimple.appRoles` **on** whenever the DSNs use `kratos_app` / `hydra_app`: initdb runs the role script
  only on an empty PGDATA. `KRATOS_APP_PASSWORD` / `HYDRA_APP_PASSWORD` must equal the passwords inside the DSNs.
  The app-roles Job is a PostSync hook: it never runs while Kratos or Hydra crash-loop on their migration init container.
  A StatefulSet does not roll a pod that never became Ready: after fixing its spec, delete the crash-looping pod.
- **Ory migrations** run as init containers (`automigration.type: initContainer`, the default for Kratos and Hydra).
  `job` is a pre-install hook (Argo PreSync) that runs before Postgres exists, and a fresh install hangs.
- **Site policy params**: the bindings use `parameterNotFoundAction: Allow` (a namespace delete cannot deadlock).
  `<ns>-site-operator-params` refuses deleting the two params ConfigMaps unless the namespace is terminating, the
  caller is in `system:masters`, or it is listed in `siteOperator.admission.paramDeleters`. Older charts (Deny)
  deadlock a namespace delete.
- **Argo CD**:
  - `ServerSideApply=true` keeps hand-added fields;
  - a `value`↔`valueFrom` switch fails the apply until the object is replaced once;
  - site-operator needs `ignoreDifferences` + `RespectIgnoreDifferences`;
  - `siteOperator.admission.ruleWriters` must name Argo's controller SA in **its** namespace.

## Questions to ask before acting

1. Which cluster context and namespace? Is it production? Is there an Argo CD app, and is it auto-sync?
2. Gateway API (which Gateway / ListenerSet, which `sectionName`) or ingress-nginx? Is cert-manager in place, and is
   DNS ready for the auth host and the app host?
3. Vault: address, KV mount and path, role name, and which service accounts it binds. Who may write Vault (you, or
   only the operator)?
4. Which components: Hydra or MCP? Sites (site-operator, gatekit, zones)? Backup (bucket, region, prefix, IRSA role)?
5. Image pinning policy: commit tags or digests? Which jinbe, kuma and login-ui versions?
6. For an upgrade: the current chart version and jinbe image, and does the new jinbe change the bootstrap schema?
7. Policy repo and branch for OPAL.

## Order of operations: a fresh install

| # | Step | Command (example names: ns `auth`, release `auth`, path `secret/data/auth`) | Expect |
|---|---|---|---|
| 1 | Vault role | `vault write auth/kubernetes/role/auth bound_service_account_names=default,kratos,auth-jinbe bound_service_account_namespaces=auth policies=auth-read` | `Success!` |
| 2 | Secrets | the `vault kv patch` block in [README › Getting started](README.md#3-write-the-secrets), including **placeholder** `OPAL_CLIENT_JWT` / `OPAL_SERVER_JWT` | no output (`>/dev/null`) |
| 3 | Values | copy `examples/minimal-values.yaml`, replace every `example.com`, the Gateway ref and the Vault fields | `helm lint . -f values.yaml` → `0 chart(s) failed` |
| 4 | Render check | `helm template auth . -n auth -f values.yaml \| grep -c 'vault:'` and look for leftovers: `grep -n example.com` | only the intended hosts |
| 5 | Install | `helm upgrade --install auth <chart> -n auth --create-namespace -f values.yaml` | Postgres, Redis, Kratos and OPAL server Ready; the OPAL client not Ready yet |
| 5b | Bootstrap (before step 6 restarts jinbe) | `kubectl -n auth logs deploy/auth-jinbe -c bootstrap \| grep -E 'First bootstrap run\|Default admin identity created\|Bootstrap complete'` | three lines |
| 6 | Mint the JWTs | the `mint` block in [README › step 5](README.md#5-mint-the-opal-jwts), then restart the OPAL server, the OPAL client and jinbe | all pods Ready |
| 8 | Sign in | the operator opens `https://<appDomain>`, signs in as `ADMIN_EMAIL`, enrols a second factor | kuma loads |
| 9 | Backup (optional) | IAM with both prefixes, `jinbe.serviceAccount.annotations`, `backup.*`; kuma → Backup → "Back up now" | `<prefix>/latest.json` exists |

## Verification checks

```sh
kubectl -n auth get pods                                    # no CrashLoopBackOff / Init:Error
kubectl -n auth get httproute -o wide                       # Accepted=True on every parent
kubectl -n auth logs deploy/auth-opal-client --since=10m | grep -ciE ' 401| 403|invalid token'   # 0
kubectl -n auth logs deploy/auth-jinbe -c bootstrap | tail -5                                   # 'Bootstrap complete' or 'converging'
curl -s -o /dev/null -w '%{http_code}\n' https://<authDomain>/login                              # 200
vault kv get -mount=<mount> -field=OPA_DECISION_TOKEN <path> | wc -c                             # >= 33, prints no secret
```

## Failure signatures → fixes

| Signature | Fix |
|---|---|
| Zone: `ListenerSet attachment from namespace <ns> not allowed`; platform HTTPRoutes unhealthy; Argo never reaches jinbe's wave | The namespace lacks the Gateway's `allowedListeners` label. Propose `syncPolicy.managedNamespaceMetadata.labels` in the Application (or a namespace label, with the operator's go), then terminate the sync and sync again. |
| Argo sync stuck "waiting for healthy state" after resources were refused | Sync operations don't retry failed resources: fix the cause, then `argocd app terminate-op <app>` and sync again (with the operator's go). |
| Kratos/Hydra schema error `doesn't validate with #/definitions/…` | A `null` in values inside the subchart config. Replace it with an explicit full list or map. |
| Site policy `no params found` with the params ConfigMap present, after a namespace recreate | A pre-C8 chart (Deny bindings, stale API-server param cache). Upgrade the chart. |
| A container fails at start with a vault-env error that a key or path was not found, or permission denied | Write the key (`kv patch`) or bind the SA to the role. The container recovers on restart. |
| jinbe `Init:Error`, bootstrap exit **6** (`MigrationNotApprovedError`) | Old-schema store: run `--plan` in a one-off Job with the new image, have the operator review it, then `--apply --expect <hash>` or set `JINBE_RBAC_APPLY_EXPECT`. Never bypass this. |
| Bootstrap exit 1 mentioning `ADMIN_PASSWORD` | Weak or short password: store a new `openssl rand -base64 24`. |
| `--apply` exit 8, or `AccessDenied` on `<prefix>-snapshots/` | Turn on the S3 backup, and add `<prefix>-snapshots/*` to IAM. |
| Everyone 403 after a restart | The OPAL client is not Ready or OPA has no data: check the JWTs (expired? placeholders?), then the OPAL server's logs. |
| Data from a new jinbe release missing in OPA | Restart the OPAL server, then the client. Set `global.jinbeRevision`. |
| Role-header gates 403/502, plain gates fine | `system.authz` refuses `/v1/data/rbac/decision`: check the rule, `OPA_DECISION_TOKEN` on opal-client (>= 32), and the proxy `opaToken` (same key). |
| Kratos → jinbe hooks 401 | The webhook secret differs, or a `vault:` string sits in the Kratos config file. Keep `auth-kratos-webhook-env`. |
| Postgres `mkdir … pgdata: Permission denied` | `fsGroup: 999` + `OnRootMismatch` (default since C8), then delete the crash-looping pod (the StatefulSet will not roll it). |
| Kratos/Hydra `password authentication failed for user "kratos_app"`; Postgres log `ignoring /docker-entrypoint-initdb.d/*` | appRoles was off at initdb. Enable it. With the operator's go, either recreate the empty volume (data loss) or run the app-roles Job by hand (it is PostSync, so it is blocked while the migrations crash-loop). |
| Fresh sync hangs on a `*-automigrate` PreSync Job | `automigration.type: job`: set `initContainer` for Kratos and Hydra, then delete the Job. |
| Namespace stuck Terminating: `<ns>-site-operator-…` denied, `no params found` | A chart from before C8. With the operator's go: `kubectl delete validatingadmissionpolicybindings -l app.kubernetes.io/instance=<release>` (a sync recreates them), or upgrade the chart. |
| Namespace stuck Terminating on `rules.oathkeeper.ory.sh` | The maester finalizer is orphaned. Only in a namespace being deleted, and with the operator's go: remove the finalizers (`kubectl patch … -p '{"metadata":{"finalizers":null}}'`). |
| Argo sync error `valueFrom: may not be specified when value is not empty` | Sync that one object with `--replace`, once. |
| Argo applies, but site rules vanish | Missing `RespectIgnoreDifferences`: the Oathkeeper config volume was reset to the seed. Add it and let site-operator re-roll. |
| Rule `platform-ready` refused by the VAP `<ns>-site-operator-rules` | Add Argo's controller SA (its real namespace) to `siteOperator.admission.ruleWriters`. |
| 403/413 on big site drafts, OpenAPI imports or MCP calls at the edge | A WAF body limit: get the operator to add a path exclusion. |

## Safe and unsafe

| Safe without asking | Ask first | Never |
|---|---|---|
| `helm template`, `helm lint`, `helm diff`, `argocd app diff`, `kubectl get/describe/logs`, `kubectl diff --server-side` | `helm upgrade`, `argocd app sync --resource …`, `kubectl rollout restart`, `vault kv patch`, Vault role changes, `bootstrap.js --plan` Job | print secrets, `vault kv put` on an existing path, `--apply` without a reviewed hash, `--allow-ephemeral-snapshot` without explicit consent, deleting PVCs or the namespace, disabling OPA auth or the NetworkPolicies, `argocd app sync` of everything with prune |
