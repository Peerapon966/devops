#!/bin/bash

set -eo pipefail

# Check for help flag first, before any other parsing
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        echo "Usage: $0 [-t|--terraform-var-file <file>] [--skip-terraform-destroy]"
        echo "  -t, --terraform-var-file  Specify terraform variables file (default: local.tfvars)"
        echo "  --skip-terraform-destroy  Don't destroy terraform resources on failure"
        echo "  -h, --help               Show this help message"
        exit 0
    fi
done

# Color codes
readonly red='\033[0;31m'
readonly green='\033[0;32m'
readonly yellow='\033[1;33m'
readonly blue='\033[0;34m'
readonly purple='\033[0;35m'
readonly cyan='\033[0;36m'
readonly nc='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${blue}[INFO]${nc} $1"
}

log_success() {
    echo -e "${green}[SUCCESS]${nc} $1"
}

log_warning() {
    echo -e "${yellow}[WARNING]${nc} $1"
}

log_error() {
    echo -e "${red}[ERROR]${nc} $1" >&2
}

log_step() {
    echo -e "\n${purple}[STEP]${nc} $1\n"
}

log_skip() {
    echo -e "${cyan}[SKIP]${nc} $1"
}

# Global state tracking
terraform_applied=false
terraform_dir=""

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code $exit_code"
        
        # Terraform cleanup
        if [[ "$terraform_applied" == "true" && -n "$terraform_dir" ]]; then
            log_warning "Attempting to destroy Terraform resources..."
            pushd "$terraform_dir" > /dev/null
            if terraform destroy -var-file "$terraform_var_file" -auto-approve; then
                log_success "Terraform resources destroyed successfully"
            else
                log_error "Failed to destroy Terraform resources - manual cleanup required!"
                log_error "Run: cd '$terraform_dir' && terraform destroy -var-file '$terraform_var_file'"
            fi
            popd > /dev/null
        fi
        
        # Clean up temporary files
        log_info "Cleaning up temporary files..."
        rm -f kubectl helm-installer.sh talos-installer.sh yq-binary
        rm -f terraform_*.zip
    fi

    # Always clean up Python venv
    if [[ -d "$venv_dir" ]]; then
        log_info "Cleaning up temporary Python venv..."
        rm -rf "$venv_dir"
    fi

    exit $exit_code
}

trap cleanup EXIT

# Detect OS and architecture
detect_os_arch() {
    local os arch
    
    case "$(uname -s)" in
        Linux*)
            os="linux"
            ;;
        Darwin*)
            os="darwin"
            ;;
        *)
            log_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
    
    case "$(uname -m)" in
        x86_64|amd64)
            arch="amd64"
            ;;
        arm64|aarch64)
            arch="arm64"
            ;;
        armv7l)
            arch="arm"
            ;;
        *)
            log_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
    
    echo "${os}_${arch}"
}

# Detect package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v brew &> /dev/null; then
        echo "brew"
    else
        log_error "No supported package manager found"
        exit 1
    fi
}

# Install system packages based on package manager
install_system_packages() {
    local pkg_manager="$1"
    shift
    local packages=("$@")
    local packages_to_install=()
    
    # Check which packages actually need to be installed
    for package in "${packages[@]}"; do
        if ! command -v "$package" &>/dev/null; then
            packages_to_install+=("$package")
        fi
    done
    
    # Only install if there are packages to install
    if [[ ${#packages_to_install[@]} -eq 0 ]]; then
        log_skip "All system packages already installed"
        return 0
    fi
    
    log_info "Installing missing packages: ${packages_to_install[*]}"
    
    case "$pkg_manager" in
        apt)
            sudo apt-get update
            sudo apt-get install -y "${packages_to_install[@]}"
            ;;
        yum)
            sudo yum install -y "${packages_to_install[@]}"
            ;;
        dnf)
            sudo dnf install -y "${packages_to_install[@]}"
            ;;
        pacman)
            sudo pacman -Sy --noconfirm "${packages_to_install[@]}"
            ;;
        brew)
            brew install "${packages_to_install[@]}"
            ;;
        *)
            log_error "Unsupported package manager: $pkg_manager"
            exit 1
            ;;
    esac
}

# Validate tool installation
validate_tool() {
    local tool="$1"
    local validation_cmd="$2"
    
    if ! eval "$validation_cmd" &> /dev/null; then
        log_error "$tool installation failed - validation command '$validation_cmd' failed"
        return 1
    fi
    return 0
}

# Terraform plan validation
validate_terraform_plan() {
    local tf_dir="$1"
    local var_file="$2"
    
    log_info "Validating Terraform plan..."
    pushd "$tf_dir" > /dev/null
    
    if ! terraform plan -var-file "$var_file" -detailed-exitcode; then
        local plan_exit_code=$?
        popd > /dev/null
        
        case $plan_exit_code in
            1)
                log_error "Terraform plan failed - configuration errors detected"
                return 1
                ;;
            2)
                log_info "Terraform plan shows changes will be made"
                return 0
                ;;
            *)
                log_error "Terraform plan failed with unexpected exit code: $plan_exit_code"
                return 1
                ;;
        esac
    fi
    
    popd > /dev/null
    log_info "Terraform plan validation successful"
    return 0
}

# Default values
script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
terraform_var_file="$script_dir/talos/terraform/vars/local.tfvars"

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--terraform-var-file)
      if [[ -z "$2" ]]; then
        log_error "Option $1 requires a value"
        exit 1
      fi
      terraform_var_file="$script_dir/talos/terraform/vars/$(basename "$2")"
      shift 2

      if [[ ! -f "$terraform_var_file" ]]; then
        log_error "Terraform variable file '$terraform_var_file' does not exist."
        exit 1
      fi
      ;;
    -h|--help)
      echo "Usage: $0 [-t|--terraform-var-file <file>]"
      echo "  -t, --terraform-var-file  Specify terraform variables file (default: local.tfvars)"
      echo "  -h, --help               Show this help message"
      exit 0
      ;;
    --skip-terraform-destroy)
      log_warning "Terraform destroy on failure is disabled"
      skip_terraform_destroy=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      echo "Usage: $0 [-t|--terraform-var-file <file>] [-h|--help] [--skip-terraform-destroy]"
      exit 1
      ;;
  esac
done

# Detect system
os_arch=$(detect_os_arch)
pkg_manager=$(detect_package_manager)
log_info "Detected system: $os_arch, package manager: $pkg_manager"

log_step "Checking sudo privileges..."
if [[ "$pkg_manager" != "brew" ]]; then
    if ! sudo -n true 2>/dev/null; then
        log_info "Requesting sudo privileges..."
        sudo -v
    fi
fi

log_step "Installing necessary packages..."

# Check if /usr/local/bin is in PATH and add if not
if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
    export PATH="$PATH:/usr/local/bin"
    
    # Only add to .bashrc if it's not already there
    if ! grep -q 'export PATH.*:/usr/local/bin' ~/.bashrc 2>/dev/null; then
        echo -e '\nexport PATH="$PATH:/usr/local/bin"' >> ~/.bashrc
        log_info "Added /usr/local/bin to PATH and ~/.bashrc"
    else
        log_info "Added /usr/local/bin to current PATH session"
    fi
fi

# System dependencies
log_info "Installing system dependencies..."
case "$pkg_manager" in
    apt)
        install_system_packages apt gnupg software-properties-common curl wget jq python3 python3-pip
        ;;
    yum|dnf)
        install_system_packages "$pkg_manager" gnupg curl wget jq python3 python3-pip
        ;;
    pacman)
        install_system_packages pacman gnupg curl wget jq python python-pip
        ;;
    brew)
        install_system_packages brew gnupg curl wget jq python3
        ;;
esac

# Terraform
if command -v terraform &> /dev/null; then
  log_skip "Terraform is already installed ($(terraform version | head -n1))"
else
  log_info "Installing Terraform..."
  case "$pkg_manager" in
    apt)
      wget -O- https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor | \
      sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
      https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
      sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt update
      sudo apt-get install -y terraform
      ;;
    yum)
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
      sudo yum -y install terraform
      ;;
    dnf)
      sudo dnf install -y dnf-plugins-core
      sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
      sudo dnf -y install terraform
      ;;
    brew)
      brew tap hashicorp/tap
      brew install hashicorp/tap/terraform
      ;;
    *)
      # Generic binary installation
      tf_version=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r .tag_name | sed 's/v//')
      tf_os_arch="${os_arch/linux_/linux_}"
      tf_os_arch="${tf_os_arch/darwin_/darwin_}"
      
      wget "https://releases.hashicorp.com/terraform/${tf_version}/terraform_${tf_version}_${tf_os_arch}.zip"
      unzip "terraform_${tf_version}_${tf_os_arch}.zip"
      sudo mv terraform /usr/local/bin/
      rm "terraform_${tf_version}_${tf_os_arch}.zip"
      ;;
  esac
  validate_tool "Terraform" "terraform version" || exit 1
  log_success "Terraform installed successfully"
fi

# Kubectl
if command -v kubectl &> /dev/null; then
  log_skip "Kubectl is already installed ($(kubectl version --client --short 2>/dev/null || echo 'version check failed'))"
else
  log_info "Installing Kubectl..."
  kubectl_os_arch="${os_arch/_//}"
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/${kubectl_os_arch}/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
  validate_tool "Kubectl" "kubectl version --client" || exit 1
  log_success "Kubectl installed successfully"
fi

# Helm
if command -v helm &> /dev/null; then
  log_skip "Helm is already installed ($(helm version --short 2>/dev/null || echo 'version check failed'))"
else
  log_info "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 > helm-installer.sh
  chmod +x helm-installer.sh
  ./helm-installer.sh
  rm helm-installer.sh
  validate_tool "Helm" "helm version" || exit 1
  log_success "Helm installed successfully"
fi

# Talosctl
if command -v talosctl &> /dev/null; then
  log_skip "Talosctl is already installed ($(talosctl version --client --short 2>/dev/null || echo 'version check failed'))"
else
  log_info "Installing Talosctl..."
  curl -sL https://talos.dev/install > talos-installer.sh
  chmod +x talos-installer.sh
  ./talos-installer.sh
  rm talos-installer.sh
  validate_tool "Talosctl" "talosctl version --client" || exit 1
  log_success "Talosctl installed successfully"
fi

# Python3 (already handled in system dependencies, just validate)
if command -v python3 &> /dev/null; then
  log_skip "Python3 is already installed ($(python3 --version))"
else
  log_error "Python3 installation failed"
  exit 1
fi

# Ansible
# Create temporary venv for Ansible
venv_name="talos-ansible-$(date +%s)"
venv_dir="/tmp/$venv_name"

log_info "Creating temporary Python virtual environment..."
python3 -m venv "$venv_dir"
source "$venv_dir/bin/activate"
pip install --upgrade pip
pip install ansible kubernetes
validate_tool "Ansible" "ansible --version" || exit 1
log_success "Ansible and kubernetes installed successfully in temporary venv: $venv_dir"

# Export the venv paths for use in the script
ansible_path="$venv_dir/bin"
export PATH="$PATH:$ansible_path"

# Ansible kubernetes.core collections
if command -v ansible-galaxy &> /dev/null; then
  if ansible-galaxy collection list kubernetes.core 2>/dev/null | grep -q kubernetes.core; then
    log_skip "kubernetes.core collection is already installed"
  else
    log_info "Installing kubernetes.core collection for Ansible..."
    ansible-galaxy collection install kubernetes.core
    log_success "kubernetes.core collection installed successfully"
  fi
else
  log_error "ansible-galaxy command not found. Ansible installation may have failed."
  exit 1
fi

# yq
if command -v yq &> /dev/null; then
  log_skip "yq is already installed ($(yq --version 2>/dev/null || echo 'version check failed'))"
else
  log_info "Installing yq..."
  case "$pkg_manager" in
    brew)
      brew install yq
      ;;
    *)
      # Generic binary installation - more reliable than PPAs
      yq_version=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r .tag_name)
      yq_os_arch="${os_arch/_//}"
      
      curl -L "https://github.com/mikefarah/yq/releases/download/${yq_version}/yq_${yq_os_arch}" -o yq-binary
      chmod +x yq-binary
      sudo mv yq-binary /usr/local/bin/yq
      ;;
  esac
  validate_tool "yq" "yq --version" || exit 1
  log_success "yq installed successfully"
fi

log_success "All necessary packages installed successfully"

# Validate required directories exist
terraform_dir="$script_dir/talos/terraform"
ansible_dir="$script_dir/talos/ansible"

if [[ ! -d "$terraform_dir" ]]; then
    log_error "Terraform directory not found: $terraform_dir"
    exit 1
fi

if [[ ! -d "$ansible_dir" ]]; then
    log_error "Ansible directory not found: $ansible_dir"
    exit 1
fi

# Deploy Terraform VM nodes
log_step "Deploying Terraform VM nodes..."
pushd "$terraform_dir" > /dev/null

log_info "Initializing Terraform..."
if ! terraform init; then
    log_error "Terraform initialization failed"
    exit 1
fi

# Validate terraform plan first
if ! validate_terraform_plan "$terraform_dir" "$terraform_var_file"; then
    log_error "Terraform plan validation failed"
    exit 1
fi

log_info "Applying Terraform configuration..."
if terraform apply -var-file "$terraform_var_file" -auto-approve; then
    terraform_applied=true
    log_success "Terraform apply completed successfully"
else
    log_error "Terraform apply failed"
    exit 1
fi

log_info "Extracting VM IP addresses..."
if ! hosts=$(terraform output -json | jq -r '.vm_ip.value'); then
    log_error "Failed to extract VM IP addresses from Terraform output"
    exit 1
fi

if [[ -z "$hosts" || "$hosts" == "null" ]]; then
    log_error "No VM IP addresses found in Terraform output"
    exit 1
fi

popd > /dev/null
log_success "Terraform deployment completed"

# Generate Ansible inventory file
log_step "Generating Ansible inventory file..."
pushd "$ansible_dir" > /dev/null

# Create inventory.yaml with template if it does not exist
if [[ ! -f inventory.yaml ]]; then
  cat > inventory.yaml <<EOF
all:
  children:
    local:
      hosts:
        localhost:
          ansible_connection: local
          ansible_python_interpreter: /usr/bin/python3
    controlplane:
      hosts:
    worker:
      hosts:
EOF
fi

echo "$hosts" | jq -c 'to_entries[]' | while read -r group; do
  host_type=$(echo "$group" | jq -r '.key')
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

if [[ ! -s inventory.yaml ]]; then
    log_error "Generated inventory file is empty"
    exit 1
fi

log_success "Ansible inventory file generated"

# Validate playbook exists
playbook_file="$ansible_dir/playbook.yaml"
if [[ ! -f "$playbook_file" ]]; then
    log_error "Ansible playbook not found: $playbook_file"
    exit 1
fi

# Set up Talos config
log_step "Setting up Talos configuration..."
log_info "Running Ansible playbook..."
if ! ansible-playbook -i inventory.yaml playbook.yaml; then
    log_error "Ansible playbook execution failed"
    exit 1
fi

log_success "Talos configuration completed successfully"

popd > /dev/null

# Disable terraform cleanup on success
terraform_applied=false

log_success "Script completed successfully!"