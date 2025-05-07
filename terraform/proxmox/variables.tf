variable "target_node" {
  description = "Node to create the VM on"
  type = string
  default = "pve"
}

variable "iso" {
  description = "Path to the ISO file"
  type = string
  default = "local:iso/talos-nocloud-amd64.iso"
}