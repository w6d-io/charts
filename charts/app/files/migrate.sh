#!/usr/bin/env bash
#
# db-migrator controller (mode b). Runs as an ArgoCD PreSync hook, in-cluster.
# 1. reads the tenant list from TENANTS (tenant identifiers separated by commas,
#    whitespace, or newlines), passed by the chart;
# 2. fans out one child migration Job per tenant (from /scripts/job.tpl.yaml, which is
#    rendered by the `liquibase` library -- Vault creds per tenant via vault-env);
# 3. by batch (BATCH_SIZE concurrent child Jobs), isolating per-tenant failures;
# 4. exits non-zero only if the failure rate exceeds FAIL_THRESHOLD_PCT (blocks the Sync).
#
set -uo pipefail

TENANTS="${TENANTS:-}"
NAMESPACE="${NAMESPACE:?}"; CHILD_TPL="${CHILD_TPL:-/scripts/job.tpl.yaml}"
RUN_ID="${RUN_ID:?}"; BATCH_SIZE="${BATCH_SIZE:-25}"
FAIL_THRESHOLD_PCT="${FAIL_THRESHOLD_PCT:-10}"; JOB_TIMEOUT="${JOB_TIMEOUT:-600}"
FAIL_FAST="${FAIL_FAST:-false}"

RESULT_DIR="$(mktemp -d)/r"; mkdir -p "$RESULT_DIR"
log() { echo "[db-migrator] $*" >&2; }

ensure_tools() {
  for b in envsubst kubectl; do command -v "$b" >/dev/null 2>&1 || MISSING=1; done
  [ -z "${MISSING:-}" ] && return 0
  if command -v apk >/dev/null 2>&1; then apk add --no-cache gettext >/dev/null 2>&1 || true
  elif command -v apt-get >/dev/null 2>&1; then apt-get update -qq && apt-get install -y -qq gettext-base >/dev/null 2>&1 || true; fi
  for b in envsubst kubectl; do command -v "$b" >/dev/null 2>&1 || { log "FATAL: $b missing"; exit 2; }; done
}

discover_tenants() {
  # Tenant identifiers from the TENANTS env (multiTenantMigration.tenants / kafka.tenants),
  # separated by commas, whitespace, or newlines.
  printf '%s' "$TENANTS" | tr -s ' \t\n,' '\n' | sed '/^$/d' | sort -u
}

migrate_one() {
  local t="$1" job="migrate-${1}-${RUN_ID}"
  kubectl -n "$NAMESPACE" delete job "$job" --ignore-not-found --wait=false >/dev/null 2>&1
  # shellcheck disable=SC2016  # ${...} is the envsubst whitelist, not to be expanded here
  if ! TENANT="$t" envsubst '${TENANT} ${RUN_ID}' < "$CHILD_TPL" \
        | kubectl -n "$NAMESPACE" apply -f - >/dev/null 2>"$RESULT_DIR/$t.err"; then
    echo "apply failed: $(tr '\n' ' ' <"$RESULT_DIR/$t.err")" >"$RESULT_DIR/$t.msg"; echo FAIL >"$RESULT_DIR/$t.status"; log "FAIL ${t}: apply failed"; return
  fi
  if kubectl -n "$NAMESPACE" wait --for=condition=complete "job/$job" --timeout="${JOB_TIMEOUT}s" >/dev/null 2>&1; then
    echo PASS >"$RESULT_DIR/$t.status"; log "PASS ${t}"
  else
    kubectl -n "$NAMESPACE" logs "job/$job" --tail=40 >"$RESULT_DIR/$t.log" 2>/dev/null || true
    echo "timeout or failed (${JOB_TIMEOUT}s)" >"$RESULT_DIR/$t.msg"; echo FAIL >"$RESULT_DIR/$t.status"; log "FAIL ${t}: timeout or failed (${JOB_TIMEOUT}s)"
  fi
}

ensure_tools
mapfile -t TENANTS < <(discover_tenants)
n="${#TENANTS[@]}"
[ "$n" -eq 0 ] && { log "FATAL: tenant list is empty"; exit 4; }
log "migrating ${n} tenant(s), batch=${BATCH_SIZE}, threshold=${FAIL_THRESHOLD_PCT}%, fail_fast=${FAIL_FAST}"

i=0; b=0
while [ "$i" -lt "$n" ]; do
  for t in "${TENANTS[@]:i:BATCH_SIZE}"; do migrate_one "$t" & done
  wait
  i=$((i+BATCH_SIZE)); b=$((b+1))
  done_ct=$(( i < n ? i : n ))
  f=$(grep -lx FAIL "$RESULT_DIR"/*.status 2>/dev/null | wc -l | tr -d ' ')
  p=$(grep -lx PASS "$RESULT_DIR"/*.status 2>/dev/null | wc -l | tr -d ' ')
  log "batch ${b}: processed ${done_ct}/${n} (OK=${p} KO=${f})"
  if [ "$FAIL_FAST" = "true" ] && [ "$f" -gt 0 ]; then
    log "FAIL-FAST: ${f} failure(s) after batch ${b} -> aborting, block Sync"
    exit 1
  fi
done

passed=0 failed=0
for t in "${TENANTS[@]}"; do
  if [ "$(cat "$RESULT_DIR/$t.status" 2>/dev/null)" = PASS ]; then passed=$((passed+1))
  else failed=$((failed+1)); log "KO ${t}: $(cat "$RESULT_DIR/$t.msg" 2>/dev/null)"; fi
done
pct=$(( failed * 100 / n ))
log "RESULT: ${passed} OK / ${failed} KO / ${n} (fail ${pct}%, threshold ${FAIL_THRESHOLD_PCT}%)"
if [ "$pct" -gt "$FAIL_THRESHOLD_PCT" ]; then log "THRESHOLD EXCEEDED -> block Sync"; exit 1; fi
log "under threshold -> Sync may proceed"; exit 0
