# vim: set filetype=sh:

set -e

function is_var_exist() {
  if [ -z "$1" ]; then
    echo "Usage : is_var_exist <var_name>"
    exit 1
  fi
  local r=$(eval echo \$"$1")
  if [ -z "$r" ]
  then
    echo "$v is mandatory"
    exit 1
  fi
}

function is_database_exist() {
  local res=$(echo "SELECT json_agg(t) from (SELECT EXISTS(SELECT datname FROM pg_catalog.pg_database WHERE lower(datname) = lower('$db_name'))) t;" | psql -U postgres -t -h ${db_host} | jq '.[] | .exists')
  #local res=$(echo "SELECT EXISTS(SELECT datname FROM pg_catalog.pg_database WHERE lower(datname) = lower('$db_name'));" | psql -U postgres -h ${db_host})
  if [ "$?" != "0" ]; then
    return 1
  fi
  #local flag=$(echo $res | grep -B1 row | head -1 | awk '{print $1}')
  if [ "$res" = "true" ]; then
    return 0
  fi
  return 1
}

for v in db_host db_name db_username db_password db_admin_username db_admin_password PGPASSWORD component
do
  is_var_exist $v
done

temp_file=$(mktemp new-XXX.sql)

pushd $(mktemp -d)

function exec_sql() {
  local file=$1
  local dbname=$2
  echo "templating $file"
  mo < "$file" > "${temp_file}"
  cat "${temp_file}"
  echo "running $file"
  psql -h "${db_host}" -d $dbname -U postgres -c "$(cat $temp_file)"
  if [ "$?" != "0" ]; then
    exit 1
  fi
}

if ! is_database_exist ; then
  exec_sql /sql/01_create_database.sql postgres
  exec_sql /sql/02_create_role.sql ${db_name}
  exec_sql /sql/03_grant_privileges.sql ${db_name}
  exec_sql /sql/04_miscellaneous.sql ${db_name}
fi

rm -f "$temp_file"