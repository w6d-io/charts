# Auth Stack Helm Chart

Umbrella chart deploying a complete authentication and authorization stack.

## Components

| Component | Description | Default |
|-----------|-------------|---------|
| **Kratos** | Ory Identity Management | enabled |
| **Oathkeeper** | Ory API Gateway / Authorization Proxy | enabled |
| **OPAL** | Open Policy Administration Layer (Server + Client + OPA) | enabled |
| **OPAL-static** | Nginx serving static policy data (bindings, roles, route_maps) | enabled |
| **Webhook** | Domain validation webhook for registration | disabled |
| **kratos-login-ui** | Self-service login UI | enabled |
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
  domain: example.com
  authDomain: auth.example.com
  appDomain: app.example.com
  imagePullSecrets: []
  vault:
    enabled: false
    address: http://vault.vault:8200
    role: ""
    envFromPath: ""
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
  enabled: false

kratosLoginUi:
  enabled: true

postgresql:
  enabled: false  # Use external DB
```

### Identity Schemas

Kratos identity schemas are configured under `kratos.kratos.identitySchemas`:
- `person` - Individual user accounts (default)

### Access Rules

Oathkeeper access rules are defined in `oathkeeper.accessRules` or via external ConfigMap.

Example rules:
- `login-ui` - Login/registration UI
- `kratos-public` - Kratos public API
- `api` - Protected API with OPA authorization
- `app` - Application static assets

### External ConfigMaps

For GitOps workflows, you can use external ConfigMaps for access rules and OPAL data:

```yaml
oathkeeper:
  externalAccessRulesConfigMap: "my-access-rules"

opalStatic:
  externalConfigMap: "my-opal-static-data"
```

### OPAL Static Data

Policy data files served by OPAL-static:
- `bindings.json` - User/group to role bindings
- `roles.json` - Role definitions per service
- `route_map.json` - Route permissions per service

Configure inline under `opalStatic.staticData`:

```yaml
opalStatic:
  staticData:
    bindings.json: |
      { "emails": {}, "groups": {} }
    roles.json: |
      { "admin": ["*"], "viewer": ["read"] }
```

## Architecture

```
                    +-------------+
                    |   Ingress   |
                    +------+------+
                           |
                    +------v------+
                    | Oathkeeper  | <-- Access Rules
                    +------+------+
                           |
         +-----------------+-----------------+
         |                 |                 |
         v                 v                 v
   +-----------+    +-----------+    +-----------+
   |  Kratos   |    |  Your API |    |  Your App |
   | (Identity)|    |  (Backend)|    |   (UI)    |
   +-----+-----+    +-----+-----+    +-----------+
         |                |
         |                v
         |         +-----------+     +-------------+
         |         | OPA/OPAL  |<----| OPAL-static |
         |         | (Authz)   |     |  (data)     |
         |         +-----------+     +-------------+
         |
         v
   +-----------+
   | PostgreSQL|
   +-----------+
```

## Useful Commands

```bash
# Test OPA authorization
kubectl port-forward svc/opal-client 8181:8181 -n auth
curl -X POST http://localhost:8181/v1/data/rbac/allow \
  -H "Content-Type: application/json" \
  -d '{"input": {"email": "user@example.com", "action": "GET", "object": "/api/resource"}}'

# Check Kratos health
kubectl port-forward svc/kratos 4433:4433 -n auth
curl http://localhost:4433/health/ready
```

## Values Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.domain` | Base domain | `example.com` |
| `global.authDomain` | Auth domain | `auth.example.com` |
| `global.appDomain` | App domain | `app.example.com` |
| `global.vault.enabled` | Enable Vault injection | `false` |
| `global.vault.address` | Vault server address | `http://vault.vault:8200` |
| `global.vault.role` | Vault role | `""` |
| `global.vault.envFromPath` | Vault secret path | `""` |
| `kratos.enabled` | Deploy Kratos | `true` |
| `oathkeeper.enabled` | Deploy Oathkeeper | `true` |
| `oathkeeper.externalAccessRulesConfigMap` | External ConfigMap for access rules | `""` |
| `opal.enabled` | Deploy OPAL | `true` |
| `opalStatic.enabled` | Deploy OPAL-static | `true` |
| `opalStatic.externalConfigMap` | External ConfigMap for static data | `""` |
| `opalStatic.replicaCount` | OPAL-static replicas | `1` |
| `webhook.enabled` | Deploy webhook | `false` |
| `webhook.domainPattern` | Allowed email domains regex | `^.*@example\\.com$` |
| `kratosLoginUi.enabled` | Deploy login UI | `true` |
| `postgresql.enabled` | Deploy PostgreSQL | `false` |
