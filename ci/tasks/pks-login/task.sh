#!/usr/bin/env bash

function login_pks() {
	(
		echo "Logging in to PKS (${PKS_API_URL})..."
		pks login -a "${PKS_API_URL}" -u "${PKS_USER}" -p "${PKS_PASSWORD}" -k
	)
}

function login_pks_k8s_cluster() {
	echo "login to pks kubernetes cluster..."
	login_pks
	pks get-credentials "${K8S_CLUSTER_NAME}"
	return 0
}

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

login_pks_k8s_cluster || exit 1

cp ~/.kube/config kube-config/config

cp ~/.pks/creds.yml pks-config/creds.yml