Vendored from github.com/w6d-io/site-operator config/admission (last sync: 0d0cc6b) (policies + bindings),
rendered by templates/site-operator/admission.yaml with release-specific names, the
release namespace and the chart's params ConfigMap. Re-copy on every site-operator change;
never edit here.

One local addition, to upstream into site-operator: route_policy.yaml carries the OAuth issuer
host exception (variable `oauth2`, params oauth2Public*), as live in auth-dev since 2026-10-01.
With the params unset it changes nothing.

Rendering (C9): templates/site-operator/admission.yaml writes every `params.data.<key>` of these files
inline as a CEL literal (the chart's own settings), drops `paramKind` and the bindings' `paramRef`, and gives
the hosts policy its Zone domains and TLS Secrets from `sites.zones`. A key it cannot inline fails the render.
Only `siteOperator.admission.zoneParams: true` keeps the hosts binding's paramRef (the operator's Zone mirror,
added to `sites.zones`). Upstream should do the same (the API server's param informer serves stale or no params
after the namespace is deleted and recreated).
