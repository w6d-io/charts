# vim: set filetype=sh:

namespace={{ .Release.Namespace }}

pushd $(mktemp -d)

# Args: secret_name
function delete_secret_if_needed(){
  local secret_name=$1
  if $(kubectl --namespace=$namespace get secret "${secret_name}-db" > /dev/null 2>&1); then
    kubectl --namespace=$namespace delete secret "${secret_name}-db"
  fi
}

delete_secret_if_needed {{ include "common.names.name" . }}
