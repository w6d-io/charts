#!/usr/bin/env bash
# With siteOperator.gateway.enabled, the chart-owned base Oathkeeper config
# (<release>-oathkeeper-config-base) must be byte-for-byte the subchart's seed config
# (<release>-oathkeeper-config). Renders every ci/*gateway*-values.yaml and compares.
set -euo pipefail
chart=$(cd "$(dirname "$0")/../charts/auth" && pwd)
fail=0
for values in "$chart"/ci/*gateway*-values.yaml; do
  out=$(helm template auth "$chart" -n auth -f "$values")
  seed=$(yq 'select(.kind == "ConfigMap" and .metadata.name == "auth-oathkeeper-config") | .data["config.yaml"]' <<<"$out")
  base=$(yq 'select(.kind == "ConfigMap" and .metadata.name == "auth-oathkeeper-config-base") | .data["config.yaml"]' <<<"$out")
  if [ -z "$base" ]; then
    echo "FAIL $(basename "$values"): no base ConfigMap rendered"; fail=1
  elif [ "$seed" != "$base" ]; then
    echo "FAIL $(basename "$values"): base != seed"; diff <(echo "$seed") <(echo "$base") || true; fail=1
  else
    echo "ok   $(basename "$values"): base == seed ($(wc -c <<<"$base" | tr -d ' ') bytes)"
  fi
done
exit $fail
