resource "proxmox_vm_qemu" "talos" {
  for_each = var.vm
  name        = each.value.name
  target_node = var.target_node
  agent = 1
  scsihw = "virtio-scsi-single"
  os_type = "6.x - 2.6 Kernel"

  onboot   = each.value.onboot
  vm_state = "running"

  memory  = each.value.memory
  cores   = each.value.cores
  sockets = each.value.sockets

  network {
    id       = 0
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = false
  }

  disks {
    ide {
      ide2 {
        cdrom {
          iso = var.iso
        }
      }
    }

    scsi {
      scsi0 {
        disk {
          size = each.value.storage_size
          storage = "local"
          iothread = true
          format = "qcow2"
          backup = true
        }
      }
    }
  }
}

output "vm_ip" {
  value = {
    for type in ["master", "worker"] : type => {
      for vm, config in var.vm : vm => proxmox_vm_qemu.talos[vm].default_ipv4_address
      if config.type == type
    }
  }
}
