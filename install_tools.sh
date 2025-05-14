#!/bin/bash

set -eo pipefail

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

echo -e "[INFO] All necessary packages installed successfully."