resource "proxmox_vm_qemu" "talos-master" {
  name        = "talos-master-2"
  target_node = var.target_node
  agent = 1
  scsihw = "virtio-scsi-single"
  os_type = "6.x - 2.6 Kernel"

  onboot   = true
  vm_state = "running"

  memory  = 4096
  cores   = 2
  sockets = 1

  network {
    id       = 0
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = false
  }

  disk {
    slot     = "scsi0"
    size     = 30
    type     = "disk"
    storage  = "local"
    iothread = true
    format = "qcow2"
    backup = true
  }
  
  disk {
    slot     = "ide2"
    type     = "cdrom"
    storage  = "local"
    iso     = var.iso
  }
}