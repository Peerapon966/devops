# Getting Started

## Prerequisites

Before beginning, ensure you have the following tools installed:
- Terraform
- Ansible
- Bash shell

## Step 1: Download Talos Linux ISO

1. Navigate to the [Talos Linux Image Factory](https://factory.talos.dev/)
2. Configure your image with these settings:
   - **Hardware Type**: `Cloud Server`
   - **Version**: Select your preferred version
   - **Cloud**: `Nocloud`
   - **Machine Architecture**: Choose based on your target hardware (amd64/arm64)
   - **System Extensions**: `siderolabs/qemu-guest-agent`

3. Download the generated ISO image
4. **Important**: Save the following information for later use:
   - Talos Schema ID
   - Talos Version

## Step 2: Configure Ansible Variables

1. Open the Ansible host variable file: [`/talos/ansible/host_vars/localhost.yaml`](ansible/host_vars/localhost.yaml)
2. Update the configuration parameters to match your environment
3. Set the following values from Step 1:
   - `schematic_id`: Your Talos Schema ID
   - `talos_version`: Your selected Talos version

## Step 3: Set Up Terraform Variables

1. Create your Terraform variables file:

```bash
cp talos/terraform/vars/example.tfvars talos/terraform/vars/local.tfvars
```

2. Edit [`/talos/terraform/vars/local.tfvars`](terraform/vars/local.tfvars) to configure your infrastructure settings according to your requirements

## Step 4: Deploy the Cluster

From the project root directory, run the deployment script:

```bash
bash deploy_cluster.sh -t talos/terraform/vars/local.tfvars
```

This command will:
- Deploy the infrastructure using Terraform
- Bootstrap the Talos cluster using Ansible
- Configure the cluster for immediate use

## Next Steps

After successful deployment, your Talos cluster will be ready for use. Refer to the cluster configuration documentation for information on accessing and managing your cluster.