#!/usr/bin/env bash

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

foundation="${1:-$FOUNDATION}"
namespace="${2:-monitoring}"
release="${3:-prometheus-operator}"
version="${4:-8.5.4}"

function usage() {
  echo "Usage:"
  echo "$0 <foundation> <namespace>"
  echo ""
  echo "foundation: ops manager foundation name"
  echo "namespace:  namespace to deploy the prometheus operator (default: monitoring)"
  exit 1
}

if [ "${1}" == "-h" ] || [ "${1}" == "help" ] || [ "${1}" == "--help" ]; then
  usage
fi

if [[ ! $(kubectl get namespace "${namespace}") ]]; then
  kubectl create namespace "${namespace}"
fi

kubectl config set-context --current --namespace="${namespace}"

cluster=$(kubectl config current-context)

./create-secrets.sh "${foundation}" "${cluster}" "${namespace}"

./interpolate.sh "${foundation}" "${cluster}"

# Copy dashboards to grafana chart location
cp dashboards/*.json charts/prometheus-operator/charts/grafana/dashboards/

bosh_exporter_enabled="$(om interpolate -s --config "environments/${foundation}/config/config.yml" --vars-file "environments/${foundation}/vars/vars.yml" --vars-env VARS --path "/clusters/cluster_name=${cluster}/bosh_exporter_enabled")"
pks_monitor_enabled="$(om interpolate -s --config "environments/${foundation}/config/config.yml" --vars-file "environments/${foundation}/vars/vars.yml" --vars-env VARS --path "/clusters/cluster_name=${cluster}/pks_monitor_enabled")"

# Copy dashboards to grafana chart location
cp dashboards/*.json charts/prometheus-operator/charts/grafana/dashboards/

# Install prometheus-operator
helm upgrade -i --version "${version}" "${release}" \
    --namespace "${namespace}" \
    --values /tmp/overrides.yaml \
    --set bosh-exporter.boshExporter.enabled="${bosh_exporter_enabled}" \
    --set pks-monitor.pksMonitor.enabled="${pks_monitor_enabled}" \
    --set global.rbac.pspEnabled=false \
    --set grafana.adminPassword=admin \
    --set grafana.testFramework.enabled=false \
    --set kubeTargetVersionOverride="$(kubectl version --short | grep -i server | awk '{print $3}' |  cut -c2-1000)" \
    ./charts/prometheus-operator

# Remove copied dashboards
rm charts/prometheus-operator/charts/grafana/dashboards/*.json