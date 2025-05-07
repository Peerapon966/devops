terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc8"
    }
  }
}

provider "proxmox" {
  pm_api_url      = "https://192.168.1.100:8006/api2/json"
  pm_user         = ""
  pm_password     = ""
  pm_tls_insecure = true
}