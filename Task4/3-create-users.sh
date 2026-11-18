#!/usr/bin/env bash
set -euo pipefail
 
# Users to create (no roles are granted)
USERS=(
  "secret-reader-user"
  "development-maintainer-user"
  "cluster-pod-reader-user"
  "infrastructure-operator-user"
)
 
PKI_DIR="${PKI_DIR:-./pki}"
CA_CERT="${HOME}/.minikube/ca.crt"
CA_KEY="${HOME}/.minikube/ca.key"
DAYS=365
 
if [[ ! -r "$CA_CERT" || ! -r "$CA_KEY" ]]; then
  echo "CA not found: ${CA_CERT} and/or ${CA_KEY}. Is minikube set up?" >&2
  exit 1
fi
 
mkdir -p "$PKI_DIR"
chmod 700 "$PKI_DIR"
 
CURRENT_CONTEXT="$(kubectl config current-context)"
CLUSTER_NAME="$(kubectl config view -o jsonpath="{.contexts[?(@.name=='${CURRENT_CONTEXT}')].context.cluster}")"
if [[ -z "$CLUSTER_NAME" ]]; then
  echo "Could not determine cluster from current kubeconfig." >&2
  exit 1
fi
 
create_user() {
  local username="$1"
  local dir="${PKI_DIR}/${username}"
  mkdir -p "$dir"
  chmod 700 "$dir"
 
  # Key + CSR (-subj avoids the interactive questions; CN = Kubernetes username)
  openssl genrsa -out "${dir}/${username}.key" 3072 2>/dev/null
  openssl req -new \
    -key "${dir}/${username}.key" \
    -out "${dir}/${username}.csr" \
    -subj "/CN=${username}"
 
  # Sign with the minikube CA
  openssl x509 -req \
    -in "${dir}/${username}.csr" \
    -CA "$CA_CERT" -CAkey "$CA_KEY" \
    -CAcreateserial -CAserial "${PKI_DIR}/ca.srl" \
    -out "${dir}/${username}.crt" \
    -days "$DAYS" -sha256 \
    -extfile <(printf "extendedKeyUsage=clientAuth\nkeyUsage=digitalSignature,keyEncipherment\n")
 
  # Add credentials and a context to kubeconfig
  kubectl config set-credentials "$username" \
    --client-certificate="${dir}/${username}.crt" \
    --client-key="${dir}/${username}.key" \
    --embed-certs=true >/dev/null
 
  kubectl config set-context "$username" \
    --cluster="$CLUSTER_NAME" \
    --user="$username" >/dev/null
 
  echo "Created user: ${username}"
}
 
for u in "${USERS[@]}"; do
  create_user "$u"
done
 
echo
echo "Contexts:"
kubectl config get-contexts
echo
echo "Switch with: kubectl config use-context <user-name>"
echo "Users have no permissions until you add RoleBindings (expect 'Forbidden')."
