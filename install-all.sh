#!/usr/bin/env bash

function usage() {
  echo "Usage:"
  echo "$0 <foundation> <namespace> <release> <dryrun>"
  echo ""
  echo "foundation: ops manager foundation name"
  echo "namespace:  namespace to deploy the prometheus operator (default: monitoring)"
  echo "release:  name of helm release to deploy the prometheus operator (default: prometheus-operator)"
  echo "dry-run  runs helm template instead of helm install. Don't modify the cluster. Template is stored at /tmp/<cluster_name>. Optional, default false"
  exit 1
}

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

foundation="${1:-$FOUNDATION}"
namespace="${2:-monitoring}"
release="${3:-prometheus-operator}"
dryrun="${4:-false}"

if [ "${1}" == "-h" ] || [ "${1}" == "help" ] || [ "${1}" == "--help" ]; then
  usage
fi

if [[ -z "${foundation}" ]]; then
  echo "Enter foundation name (e.g. haas-000): "
  read -r foundation
fi

if [ -z "${dryrun}" ]; then
  dryrun=false
fi


__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090
source "${__DIR}/scripts/target-bosh.sh"

# shellcheck disable=SC1090
source "${__DIR}/scripts/helpers.sh"

clusters="$(pks clusters --json | jq -r 'sort_by(.name) | .[] | select(.last_action_state=="succeeded") | .name')"
for cluster in ${clusters}; do
  printf "Installing %s into %s\n" "${release}" "${cluster}"
  if ${dryrun}
  then
  #if [ ${dryrun} ]; then
     # body
     echo "** dry run **"
     echo "templating to /tmp/${cluster}"
     template_cluster "${foundation}" "${cluster}" "${namespace}" "${release}"
     continue
  fi

  install_cluster "${foundation}" "${cluster}" "${namespace}" "${release}"
done
