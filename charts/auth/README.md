# W6D Auth Stack

Enterprise authentication & authorization platform. One Helm install, zero-config RBAC.

## Architecture

```
Browser → Oathkeeper (gateway) → Kratos (session) → OPA (policy) → Your Service
                ↑                                       ↑
          polls rules from                    data pushed by OPAL
                ↑                                       ↑
              Jinbe ──── Redis (RBAC store) ──── OPAL Server
              (brain)                          (real-time push)
```

## Components

| Component | Description | Default |
|-----------|-------------|---------|
| **Jinbe** | RBAC control plane — admin API, OPA bundles, Oathkeeper rules | enabled |
| **Redis** | RBAC data store + audit event streams | enabled |
| **Kratos** | Ory Identity Management (sessions, OIDC, MFA) | enabled |
| **Oathkeeper** | Ory API Gateway (routes, auth, authorization) | enabled |
| **OPAL** | Real-time policy push via WebSocket (Server + Client + OPA) | enabled |
| **OPA-AuthZ-Proxy** | Translates OPA decisions to HTTP | enabled |
| **Kratos Login UI** | Branded login/register pages | enabled |

## Quick Start

```bash
# From chart repo (all subcharts bundled — no external repos needed)
helm install auth w6dio/auth \
  --set global.domain=mycompany.com \
  --set kratos.kratos.config.dsn=postgresql://user:pass@db:5432/kratos \
  --set jinbe.env.ENCRYPTION_KEY=$(openssl rand -base64 32) \
  --set opal.server.policyRepoUrl=https://github.com/your-org/rbac-policies.git

# Or from local clone
helm install auth ./charts/auth --values my-values.yaml
```

First user to register gets `super_admin` access. Done.

## Required Values

| Value | Description | Example |
|-------|-------------|---------|
| `global.domain` | Base domain (everything derives from it) | `mycompany.com` |
| `kratos.kratos.config.dsn` | PostgreSQL connection for Kratos | `postgresql://...` |
| `jinbe.env.ENCRYPTION_KEY` | Encryption key (min 32 chars) | `$(openssl rand -base64 32)` |
| `opal.server.policyRepoUrl` | Git repo with `rbac.rego` policy | `https://github.com/...` |

Everything else is auto-computed from Release name + domain.

## Auto-Computed URLs

All inter-service URLs are templated from `{{ .Release.Name }}`:

| Service | URL |
|---------|-----|
| Redis | `redis://{release}-redis-master:6379` |
| Kratos Public | `http://{release}-kratos-public:80` |
| Kratos Admin | `http://{release}-kratos-admin:80` |
| OPA | `http://{release}-opal-client:8181` |
| OPAL Server | `http://{release}-opal-server:7002` |
| Jinbe | `http://{release}-auth-jinbe:8080` |
| Oathkeeper rules | `http://{release}-auth-jinbe:8080/api/oathkeeper/rules` |

## RBAC Model

```
User (Kratos identity)
  └── Group (super_admins, admins, devs, viewers)
       └── Role per service (admin, editor, viewer)
            └── Permissions (resource:action format)
                 └── Route map (method + path → permission)
```

### Default Groups (auto-created on first boot)

| Group | Description |
|-------|-------------|
| `super_admins` | Global `*` wildcard — full access to everything |
| `admins` | Per-service admin role |
| `devs` | Per-service editor role |
| `viewers` | Per-service read-only |
| `users` | No default permissions |

### Permission Format

All permissions use `resource:action`: `clusters:list`, `databases:delete`, `admin:read`.
Wildcard `*` grants all permissions.

## Jinbe API Endpoints

| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /api/health` | Public | Health check (includes Redis status) |
| `GET /api/opa/bundle` | Public | OPA policy bundle (tar.gz) |
| `GET /api/oathkeeper/rules` | Public | Oathkeeper access rules (JSON) |
| `GET /api/admin/rbac/groups` | Admin | List groups |
| `POST /api/admin/rbac/groups` | Admin | Create group |
| `PUT /api/admin/rbac/groups/:name` | Admin | Update group |
| `DELETE /api/admin/rbac/groups/:name` | Admin | Delete group |
| `GET /api/admin/rbac/services` | Admin | List services |
| `POST /api/admin/rbac/services` | Admin | Create service (auto-generates roles, routes, rules) |
| `DELETE /api/admin/rbac/services/:name` | Admin | Delete service |
| `GET /api/admin/rbac/access-rules` | Admin | List Oathkeeper rules |
| `POST /api/admin/rbac/simulate` | Admin | Permission simulator |
| `GET /api/admin/audit/events` | Admin | Audit event log |
| `GET /api/admin/rbac/users` | Admin | Users with group matrix |

## Data Flow

### Request Authorization (<1ms)
```
Oathkeeper → cookie_session(Kratos) → remote_json(OPA) → allow/deny
```

### RBAC Change Propagation (<100ms)
```
Admin → Jinbe API → Redis → POST OPAL server → WebSocket push → all OPA replicas
```

### Oathkeeper Rule Updates (~30s)
```
Admin creates service → Jinbe writes to Redis → Oathkeeper polls HTTP endpoint
```

## Configuration Reference

### Global

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.domain` | Base domain | `example.com` |
| `global.authDomain` | Auth domain override | `auth.{domain}` |
| `global.appDomain` | App domain override | `app.{domain}` |
| `global.vault.enabled` | Enable Vault injection | `false` |

### Jinbe

| Parameter | Description | Default |
|-----------|-------------|---------|
| `jinbe.enabled` | Deploy Jinbe | `true` |
| `jinbe.image.repository` | Image | `ghcr.io/w6d-io/jinbe-api` |
| `jinbe.image.tag` | Tag | `appVersion` |
| `jinbe.service.port` | Service port | `8080` |
| `jinbe.env.ENCRYPTION_KEY` | **Required** — encryption key | — |
| `jinbe.env.NODE_ENV` | Environment | `production` |
| `jinbe.env.CORS_ORIGIN` | CORS allowlist | Auto-computed |
| `jinbe.env.REDIS_URL` | Redis URL | Auto-computed |
| `jinbe.extraEnv` | Additional env vars (map) | `{}` |
| `jinbe.podAnnotations` | Pod annotations (Vault, etc.) | `{}` |

### Redis

| Parameter | Description | Default |
|-----------|-------------|---------|
| `redis.enabled` | Deploy Redis | `true` |
| `redis.architecture` | Standalone or replication | `standalone` |
| `redis.auth.enabled` | Require password | `false` |
| `redis.master.persistence.size` | Storage | `1Gi` |

### OPAL

| Parameter | Description | Default |
|-----------|-------------|---------|
| `opal.enabled` | Deploy OPAL | `true` |
| `opal.server.policyRepoUrl` | **Required** — Git repo with rego | — |
| `opal.server.pollingInterval` | Git poll interval | `30` |
| `opal.server.broadcastPgsql` | Use PostgreSQL for broadcast | `false` |

### Oathkeeper

| Parameter | Description | Default |
|-----------|-------------|---------|
| `oathkeeper.enabled` | Deploy Oathkeeper | `true` |
| `oathkeeper.ingress.proxy.enabled` | Expose via ingress | `false` |

### Kratos

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kratos.enabled` | Deploy Kratos | `true` |
| `kratos.kratos.config.dsn` | **Required** — PostgreSQL DSN | — |

## Vault Integration

Add Vault annotations to inject secrets:

```yaml
jinbe:
  podAnnotations:
    vault.security.banzaicloud.io/vault-addr: "http://vault.vault:8200"
    vault.security.banzaicloud.io/vault-role: "auth"
    vault.security.banzaicloud.io/vault-env-from-path: "infra/data/auth"
  env:
    ENCRYPTION_KEY: "vault:infra/data/auth#ENCRYPTION_KEY"
```

## Adding a New Service

```bash
# Via Jinbe API (creates roles + route_map + Oathkeeper rule)
curl -X POST https://app.mycompany.com/api/admin/rbac/services \
  -H "Cookie: ory_kratos_session=..." \
  -d '{"name": "myapp", "upstreamUrl": "http://myapp:8080"}'
```

This auto-creates:
- Default roles (admin, operator, editor, viewer) with `resource:action` permissions
- Health endpoint in route map
- Oathkeeper access rule (cookie_session + remote_json)
- Adds default roles to standard groups
