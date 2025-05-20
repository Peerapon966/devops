variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
}

variable "target_node" {
  description = "Node to create the VM on"
  type = string
}

variable "iso" {
  description = "Path to the ISO file"
  type = string
}

variable "vm" {
  description = "configuration for the VM"
  type = map(object({
    name         = string
    type         = string
    onboot       = bool
    memory       = number
    cores        = number
    sockets      = number
    storage_size = number
  }))

  validation {
    condition = alltrue([
      for vm in var.vm : contains(["master", "worker"], vm.type)
    ])
    error_message = "Each VM must have a type of either 'master' or 'worker'."
  }
}
