pm_api_url = "https://192.168.1.100:8006/api2/json"
pm_api_token_id = "xxx@pve!xxx"
pm_api_token_secret = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
target_node = "pve"
iso = "local:iso/talos-nocloud-amd64.iso"
vm = {
  master-1 = {
    name        = "talos-master-1"
    onboot      = true
    memory      = 4096
    cores       = 2
    sockets     = 1
    storage_size = 32
  },
  master-2 = {
    name        = "talos-master-2"
    onboot      = true
    memory      = 4096
    cores       = 2
    sockets     = 1
    storage_size = 32
  },
  master-3 = {
    name        = "talos-master-3"
    onboot      = true
    memory      = 4096
    cores       = 2
    sockets     = 1
    storage_size = 32
  },
  worker-1 = {
    name        = "talos-worker-1"
    onboot      = true
    memory      = 8192
    cores       = 2
    sockets     = 1
    storage_size = 32
  },
  worker-2 = {
    name        = "talos-worker-2"
    onboot      = true
    memory      = 8192
    cores       = 2
    sockets     = 1
    storage_size = 32
  },
}