#!/bin/bash

set -eo pipefail

# Default values
script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
terraform_var_file="$script_dir/talos/terraform/vars/local.tfvars"

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--terraform-var-file)
      terraform_var_file="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: $0 [-t value] [--terraform-var-file value]"
      exit 1
      ;;
    *)
      shift
      ;;
  esac
done

echo -e "\n[INFO] Trigger sudo password prompt if sudo session is already expired or not running as root...\n"
sudo -v

# install necessary packages
echo "[INFO] Installing necessary packages..."

# Terraform
if [[ "$(which terraform | wc -l)" -ge 1 ]]; then
  echo "[INFO] Terraform is already installed, skipping installation."
else
  echo -e "[INFO] Installing Terraform...\n"
  sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
  wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt update
  sudo apt-get install -y terraform
fi

# Kubectl
if [[ "$(which kubectl | wc -l)" -ge 1 ]]; then
  echo "[INFO] Kubectl is already installed, skipping installation."
else
  echo -e "[INFO] Installing Kubectl...\n"
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
fi

# Talosctl
if [[ "$(which talosctl | wc -l)" -ge 1 ]]; then
  echo "[INFO] Talosctl is already installed, skipping installation."
else
  echo -e "[INFO] Installing Talosctl...\n"
  curl -sL https://talos.dev/install | sh
fi

# Python3
if [[ "$(which python3 | wc -l)" -ge 1 ]]; then
  echo "[INFO] Python3 is already installed, skipping installation."
else
  echo -e "[INFO] Installing Python3...\n"
  sudo apt install -y python3 python3-pip
fi

# Ansible
if [[ "$(which ansible | wc -l)" -ge 1 ]]; then
  echo "[INFO] Ansible is already installed, skipping installation."
else
  echo -e "[INFO] Installing Ansible...\n"
  python3 -m pip install --upgrade pip
  python3 -m pip install --user ansible
  export PATH="$PATH:$HOME/.local/bin"
  echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
fi

# yq
if [[ "$(which yq | wc -l)" -ge 1 ]]; then
  echo "[INFO] yq is already installed, skipping installation."
else
  echo -e "[INFO] Installing yq...\n"
  sudo add-apt-repository ppa:rmescandon/yq
  sudo apt update
  sudo apt install -y yq
  sudo yq shell-completion bash | sudo tee /etc/bash_completion.d/yq > /dev/null
fi

echo -e "[INFO] All necessary packages installed successfully."

# Deploy Terraform VM nodes
echo -e "\n[INFO] Deploying Terraform VM nodes...\n"
pushd "$script_dir/talos/terraform" > /dev/null

terraform init
terraform apply -var-file "$terraform_var_file" -auto-approve

hosts=$(terraform output -json | jq -r '.vm_ip.value')

popd > /dev/null

# Generate Ansible inventory file
echo -e "\n[INFO] Generating Ansible inventory file...\n"
pushd "$script_dir/talos/ansible" > /dev/null

echo "$hosts" | jq -c 'to_entries[]' | while read -r group; do
  host_type=$(echo "$group" | jq -r '.key')  # "master" or "worker"

  # Map "master" → "controlplane", "worker" → "worker"
  group_key=$([ "$host_type" = "master" ] && echo "controlplane" || echo "worker")

  echo "$group" | jq -c '.value | to_entries[]' | while read -r host; do
    host_name=$(echo "$host" | jq -r '.key')
    host_ip=$(echo "$host" | jq -r '.value')

    yq e -i ".all.children.${group_key}.hosts.${host_name} = {
      \"ansible_host\": \"${host_ip}\",
      \"ip\": \"${host_ip}\"
    }" inventory.yaml
  done
done

# Set up Talos config
echo -e "\n[INFO] Setting up Talos config...\n"
ansible-playbook -i inventory.yaml playbook.yaml
echo -e "\n[INFO] Talos config set up successfully."