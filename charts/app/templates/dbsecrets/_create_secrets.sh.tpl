# vim: set filetype=sh:

namespace={{ .Release.Namespace }}
release={{ .Release.Name }}

pushd $(mktemp -d)

function label_secret(){
  local secret_name=$1
  local label_name=$2
  kubectl --namespace=$namespace label \
    --overwrite \
    secret "${secret_name}-db" "app.kubernetes.io/managed-by"="Helm" "app.kubernetes.io/extra-name"="$label_name" {{ include "common.labels.standard" . | replace ": " "=" | replace "\r\n" " " | replace "\n" " " }}
  kubectl --namespace=$namespace annotate \
    --overwrite \
    secret "${secret_name}-db" "meta.helm.sh/release-name"={{ print .Release.Name }} "meta.helm.sh/release-namespace"=$namespace
}

# Args: secret_name, args
function create_secret_if_needed(){
  local secret_args=( "${@:2}")
  local secret_name=$1

  if ! $(kubectl --namespace=$namespace get secret "${secret_name}-db" > /dev/null 2>&1); then
    kubectl --namespace=$namespace create secret generic "${secret_name}-db" ${secret_args[@]}
  else
    echo "secret ${secret_name}-db already exists."
      for arg in "${secret_args[@]}"; do
        local from=$(echo -n ${arg} | cut -d '=' -f1)
        if [ -z "${from##*literal*}" ]; then
          local key=$(echo -n ${arg} | cut -d '=' -f2)
          local desiredValue=$(echo -n ${arg} | cut -d '=' -f3-)
          local flags="--namespace=$namespace --allow-missing-template-keys=false"
          if ! $(kubectl $flags get secret "${secret_name}-db" -ojsonpath="{.data.${key}}" > /dev/null 2>&1); then
            echo "key \"${key}\" does not exist. patching it in."
            if [ "${desiredValue}" != "" ]; then
              desiredValue=$(echo -n "${desiredValue}" | base64 -w 0)
            fi
            kubectl --namespace=$namespace patch secret "${secret_name}-db" -p "{\"data\":{\"$key\":\"${desiredValue}\"}}"
          fi
        fi
      done
  fi
}

create_secret_if_needed {{ template "common.names.fullname" . }} \
--from-literal=postgres-password={{ required "database.password is required" .Values.database.password | quote }} \
--from-literal=dlm-postgres-password={{ required "database.adminpassword is required" .Values.database.adminpassword | quote }}

label_secret {{ template "common.names.fullname" . }} {{ include "common.component" . | quote }}
