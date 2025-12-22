# Auth Stack Helm Chart

Umbrella chart deploying a complete authentication and authorization stack.

## Components

| Component | Description | Default |
|-----------|-------------|---------|
| **Kratos** | Ory Identity Management | enabled |
| **Oathkeeper** | Ory API Gateway / Authorization Proxy | enabled |
| **OPAL** | Open Policy Administration Layer (Server + Client + OPA) | enabled |
| **OPAL-static** | Nginx serving static policy data (bindings, roles, route_maps) | enabled |
| **Webhook** | Domain validation webhook for registration | enabled |
| **kratos-login-ui** | Self-service login UI | disabled |
| **PostgreSQL** | Bitnami PostgreSQL for Kratos | disabled |

## Installation

```bash
# Add required repos
helm repo add ory https://k8s.ory.sh/helm/charts
helm repo add permitio https://permitio.github.io/opal-helm-chart
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update dependencies
cd charts/auth && helm dependency update

# Install
helm install auth . -n auth --create-namespace

# With custom values
helm install auth . -n auth -f my-values.yaml
```

## Configuration

### Global Settings

```yaml
global:
  domain: dev.w6d.io
  authDomain: auth.dev.w6d.io
  appDomain: kuma.dev.w6d.io
  imagePullSecrets: []
  vault:
    enabled: true
    address: http://vault.vault:8200
    role: kratos-poc
    envFromPath: infra/data/kratos-poc
```

### Vault Integration

When `global.vault.enabled: true`, Banzai Cloud Vault annotations are automatically injected into pods that need secrets:

- Kratos deployment and jobs
- Webhook deployment

Annotations added:
```yaml
vault.security.banzaicloud.io/vault-addr: <address>
vault.security.banzaicloud.io/vault-role: <role>
vault.security.banzaicloud.io/vault-env-from-path: <envFromPath>
```

### Enable/Disable Components

```yaml
kratos:
  enabled: true

oathkeeper:
  enabled: true

opal:
  enabled: true

opalStatic:
  enabled: true

webhook:
  enabled: true

kratos-login-ui:
  enabled: false

postgresql:
  enabled: false  # Use external DB
```

### Identity Schemas

Kratos identity schemas are configured under `kratos.kratos.identitySchemas`:
- `person` - Individual user accounts
- `organisation` - Organization accounts
- `group` - Group accounts

### Access Rules

Oathkeeper access rules are defined in `oathkeeper.accessRules`. Default rules:
- `selfservice-ui` - Login/registration UI
- `kratos-public` - Kratos public API
- `jinbe` - Jinbe API with OPA authorization
- `kuma-root` - Kuma root path
- `kuma` - Kuma static assets

### OPAL Static Data

Policy data files served by OPAL-static:
- `bindings.json` - User/group to role bindings
- `roles.*.json` - Role definitions per service
- `route_map.*.json` - Route permissions per service

Configure under `opalStatic.staticData`:

```yaml
opalStatic:
  staticData:
    bindings.json: |
      { "bindings": [...] }
    roles.jinbe.json: |
      { "roles": {...} }
```

## Architecture

```
                    ┌─────────────┐
                    │   Ingress   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ Oathkeeper  │ ◄── Access Rules
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
   ┌───────────┐    ┌───────────┐    ┌───────────┐
   │  Kratos   │    │   Jinbe   │    │   Kuma    │
   │ (Identity)│    │   (API)   │    │   (UI)    │
   └─────┬─────┘    └─────┬─────┘    └───────────┘
         │                │
         │                ▼
         │         ┌───────────┐     ┌─────────────┐
         │         │ OPA/OPAL  │◄────│ OPAL-static │
         │         │ (Authz)   │     │  (data)     │
         │         └───────────┘     └─────────────┘
         │
         ▼
   ┌───────────┐
   │ PostgreSQL│
   └───────────┘
```

## Useful Commands

```bash
# Test OPA authorization
kubectl port-forward svc/opal-client 8181:8181 -n auth
curl -X POST http://localhost:8181/v1/data/rbac/allow \
  -H "Content-Type: application/json" \
  -d '{"input": {"email": "user@w6d.io", "app": "jinbe", "action": "GET", "object": "/api/clusters/"}}'

# Get user info from OPA
curl -X POST http://localhost:8181/v1/data/rbac/user_info \
  -H "Content-Type: application/json" \
  -d '{"input": {"email": "user@w6d.io", "app": "jinbe"}}'

# Check Kratos health
kubectl port-forward svc/kratos 4433:4433 -n auth
curl http://localhost:4433/health/ready
```

## Values Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.domain` | Base domain | `dev.w6d.io` |
| `global.authDomain` | Auth domain | `auth.dev.w6d.io` |
| `global.appDomain` | App domain | `kuma.dev.w6d.io` |
| `global.vault.enabled` | Enable Vault injection | `true` |
| `global.vault.address` | Vault server address | `http://vault.vault:8200` |
| `global.vault.role` | Vault role | `kratos-poc` |
| `global.vault.envFromPath` | Vault secret path | `infra/data/kratos-poc` |
| `kratos.enabled` | Deploy Kratos | `true` |
| `oathkeeper.enabled` | Deploy Oathkeeper | `true` |
| `opal.enabled` | Deploy OPAL | `true` |
| `opalStatic.enabled` | Deploy OPAL-static | `true` |
| `opalStatic.replicaCount` | OPAL-static replicas | `1` |
| `webhook.enabled` | Deploy webhook | `true` |
| `webhook.domainPattern` | Allowed email domains | `^.+@w6d\\.io$` |
| `kratos-login-ui.enabled` | Deploy login UI | `false` |
| `postgresql.enabled` | Deploy PostgreSQL | `false` |
