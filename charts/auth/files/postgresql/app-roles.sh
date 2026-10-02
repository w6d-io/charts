#!/bin/sh
# Creates each app role and its database (postgresqlSimple.appRoles). Runs as an initdb script on
# an empty volume (local socket, POSTGRES_USER) and as the hook Job on existing volumes (PGHOST,
# PGUSER, PGPASSWORD). APP_ROLES="role:db ...", APP_ROLE_<n>_PASSWORD per entry, same order.
set -eu
export PGUSER="${PGUSER:-${POSTGRES_USER:-postgres}}"
n=0
for entry in $APP_ROLES; do
  role="${entry%%:*}"
  db="${entry#*:}"
  eval "pw=\${APP_ROLE_${n}_PASSWORD:-}"
  if [ "${#pw}" -lt 16 ]; then
    echo "app-roles: the password of ${role} is shorter than 16 characters" >&2
    exit 1
  fi
  psql -X -q -d postgres -v ON_ERROR_STOP=1 -v role="$role" -v db="$db" -v pw="$pw" -f /app-roles/app-roles.sql
  echo "app-roles: ${role} owns ${db}"
  n=$((n + 1))
done
