Vendored from github.com/w6d-io/site-operator config/admission (last sync: 0d0cc6b) (policies + bindings),
rendered by templates/site-operator/admission.yaml with release-specific names, the
release namespace and the chart's params ConfigMap. Re-copy on every site-operator change;
never edit here.

One local addition, to upstream into site-operator: route_policy.yaml carries the OAuth issuer
host exception (variable `oauth2`, params oauth2Public*), as live in auth-dev since 2026-10-01.
With the params unset it changes nothing.
