#!/bin/bash

set -euo pipefail

root_dir="$(dirname -- $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd))"

pushd "${root_dir}/vault/terraform" > /dev/null 2>&1
kubectl apply -f assets/k8s/token-reviewer-jwt.yaml
token=$(kubectl get secret vault-token-reviewer-jwt -n vault -o jsonpath='{.data.token}' | base64 --decode)

terraform init -reconfigure
terraform apply -var-file=tfvars/local.tfvars -var="token_reviewer_jwt=${token}" -auto-approve
popd

echo "Vault init successfully"