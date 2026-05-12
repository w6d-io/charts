# Gotenberg

Helm chart for [Gotenberg](https://gotenberg.dev/) — a stateless API for Office → PDF conversion.

Modelled on the [`nager`](../nager) chart structure with extensions for Gotenberg's runtime needs:
read-only root filesystem with tmpfs scratch volumes, strict pod security, Linkerd policy with
`apiVersion` toggle for older meshes, and per-policy NetworkPolicy list.

## Installation

```bash
helm install gotenberg ./charts/gotenberg -n gotenberg --create-namespace
```

## Linkerd version toggle

The Server CRD uses different `apiVersion` across Linkerd releases. Set `linkerd.serverApiVersion`
to match your cluster:

| Linkerd release | `linkerd.serverApiVersion` |
| --- | --- |
| ≥ 2.15 / edge-25.x | `policy.linkerd.io/v1beta3` *(default)* |
| ≤ 2.14 | `policy.linkerd.io/v1beta1` |

Mismatch on this single field was the root cause of incident SIS-2152 — qualif on Linkerd 2.14
rejected a `v1beta3` manifest. The chart prevents the regression as long as the env-specific
values file is correct.

## Values overview

| Key | Default | Notes |
| --- | --- | --- |
| `replicaCount` | `1` | |
| `image.repository` | `gotenberg/gotenberg` | |
| `image.tag` | `""` (= `Chart.AppVersion`, `8`) | |
| `args` | `[gotenberg, --api-port=3000, --api-timeout=60s]` | First element must be `gotenberg`. |
| `containerPort` | `3000` | |
| `service.port` | `3000` | Matches `containerPort` by default. |
| `podSecurityContext` | `runAsNonRoot:true, runAsUser/Group/fsGroup:1001, seccomp:RuntimeDefault` | |
| `securityContext` | `allowPrivilegeEscalation:false, readOnlyRootFilesystem:true, capabilities.drop:[ALL]` | |
| `volumes.tmp` | `emptyDir { medium: Memory, sizeLimit: 256Mi }` | Mounted at `/tmp/gotenberg`. |
| `volumes.home` | `emptyDir { sizeLimit: 64Mi }` | Mounted at `/home/gotenberg`. |
| `automountServiceAccountToken` | `false` | Pod and SA. |
| `namespace.create` | `false` | Leave false when Argo creates the namespace. |
| `linkerd.enabled` | `true` | Render Server + AuthorizationPolicy. |
| `linkerd.serverApiVersion` | `policy.linkerd.io/v1beta3` | Override to `v1beta1` on older meshes. |
| `networkPolicies` | 3 entries — default-deny, allow-time-tenants-ingress, allow-egress-dns | Each entry is rendered verbatim. `podSelector` defaults to the chart selectorLabels if omitted. |

## NetworkPolicies

Chart defaults are zero-trust generic and apply everywhere Gotenberg runs:

- `default-deny` — closes both Ingress and Egress on every pod in the namespace.
- `allow-egress-dns` — allows DNS (UDP/TCP 53) to `kube-system/kube-dns`.

**Ingress allow rules are not in the chart** — they depend on which client
namespaces and pod labels are allowed to reach Gotenberg, which is deployment-
specific (different namespace selectors / pod labels across envs). Add them
in your consumer values file, e.g.:

```yaml
networkPolicies:
  - name: default-deny
    podSelector: {}
    policyTypes: [Ingress, Egress]
  - name: allow-clients-ingress
    policyTypes: [Ingress]
    ingress:
      - from:
          - namespaceSelector:
              matchLabels:
                <your-namespace-label>: <value>
            podSelector:
              matchLabels:
                <your-client-pod-label>: <value>
        ports:
          - port: 3000
            protocol: TCP
  - name: allow-egress-dns
    policyTypes: [Egress]
    egress:
      # ...same as chart default
```

Note: `networkPolicies` is a list, and Helm/yq value-merges replace lists
entirely (no concatenation). Redefine the full list in your env values when
adding rules.

### Linkerd identity vs NetworkPolicy

The Linkerd `AuthorizationPolicy` rendered by this chart is `allow-all`
(`requiredAuthenticationRefs: []`). If the consumer namespaces fan out
(e.g. one per tenant), enumerating each one as a `MeshTLSAuthentication`
identity is not practical and L7 identity restriction stays off — L3/L4
NetworkPolicy gates access. If you have a small fixed set of clients, swap
the `allow-all` for an explicit list (see `charts/app/templates/linkerd/policy.yaml`
for a pattern that fits in this chart).
