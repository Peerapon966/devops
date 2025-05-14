# Getting started

1. Download a Talos Linux ISO image from [Talos Linux Image Factory](https://factory.talos.dev/). The image should have the following settings

- Hardware Type: Cloud Server
- Version: <you choose it>
- Cloud: Nocloud
- Machine Architecture: <you choose it>
- System Extensions: siderolabs/qemu-guest-agent

Also memo the Talos schema ID and Talos version somewhere, we'll need them later

2. Run the following command to install necessary tools, the required tools that will be installed by this script are

- Terraform
- Kubectl
- Talosctl
- Python3
- Ansible

```bash
bash install_tools.sh
```

3. Configure Terraform variable to match your need, you can use the `example.tfvars` or create your own variable file if you want

Then run this command in the `terraform` directory to spin up Talos VM

```bash
terraform apply -var-file=<your_tfvars_file> -auto-approve
```

After terraform done its job, you should see a list of VMs' IP address as a terraform output

4.
