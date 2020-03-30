
export TEMP_DIR=$(mktemp -d)

printf "\n==== Download Istio to %s \n" "$TEMP_DIR"  
(cd $TEMP_DIR && curl -L https://istio.io/downloadIstio | sh -)
istioDir=$(ls $TEMP_DIR)

printf "\n====== Log in %s \n" "PKS"  
source ./login-pks.sh


clusters="$(pks clusters --json | jq -r 'sort_by(.name) | .[] | select(.name | contains("clus0")) | .name')"
for cluster in ${clusters}; do
  printf "\n==== Log in to cluster %s \n" "${cluster}"  
  kubectl config use-context "${cluster}"

  printf "\n\n==== Install %s into %s ====" "Istio" "${cluster}"
  printf "\n====== Apply Istio CRDS into %s \n" "${cluster}"  
  kubectl create namespace istio-system
  helm template "$TEMP_DIR/$istioDir/install/kubernetes/helm/istio-init" \
    --namespace istio-system | kubectl apply -f -

  printf "\n====== Install Istio Helm Chart into %s \n" "${cluster}"  
  helm template "$TEMP_DIR/$istioDir/install/kubernetes/operator/operator-chart/" \
    --set hub=docker.io/istio \
    --set tag=1.5.1 \
    --set operatorNamespace=istio-operator \
    --set istioNamespace=istio-system | kubectl apply -f -

printf "\n==== Instal %s into %s \n" "OPA Gatekeeper" "${cluster}"
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
done
