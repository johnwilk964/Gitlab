terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

# ------------------------------------------------------------------ #
#  Provider (NO HARDCODED SECRETS)                                   #
# ------------------------------------------------------------------ #
provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = var.proxmox_insecure
}

# ------------------------------------------------------------------ #
#  Sensitive Connection Variables                                    #
# ------------------------------------------------------------------ #
variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Allow insecure TLS (true for self-signed)"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------ #
#  VM Configuration Variables                                        #
# ------------------------------------------------------------------ #
variable "template_id" {
  type    = number
  default = 1005
}

variable "target_node" {
  type    = string
  default = "prox2"
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4096
}

variable "disk_size" {
  type    = number
  default = 64
}

# ------------------------------------------------------------------ #
#  Locals                                                            #
# ------------------------------------------------------------------ #
locals {
  vms = {
    "Win11-CBC01" = { vm_id = 302 }
    "Win11-CBC02" = { vm_id = 303 }
    "Win11-CBC03" = { vm_id = 304 }
  }
}

# ------------------------------------------------------------------ #
#  VM Resources                                                      #
# ------------------------------------------------------------------ #
resource "proxmox_virtual_environment_vm" "win11_cbc" {
  for_each  = local.vms

  name      = each.key
  vm_id     = each.value.vm_id
  node_name = var.target_node

  clone {
    vm_id     = var.template_id
    full      = true
    node_name = var.target_node
  }

  operating_system {
    type = "win11"
  }

  cpu {
    cores   = var.cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = "Thinpool1"
    interface    = "virtio0"
    size         = var.disk_size
    discard      = "on"
    iothread     = true
    cache        = "writeback"
  }

  network_device {
    bridge = "vmbr1"
    model  = "virtio"
  }

  agent {
    enabled = true
    timeout = "15m"
  }

  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["virtio0"]

  started  = true
  on_boot  = true

  timeout_clone    = 1800
  timeout_create   = 1800
  timeout_start_vm = 1800
}

# ------------------------------------------------------------------ #
#  Outputs (safe)                                                    #
# ------------------------------------------------------------------ #
output "vm_names" {
  value = {
    for k, v in proxmox_virtual_environment_vm.win11_cbc :
    k => v.name
  }
}

output "vm_ids" {
  value = {
    for k, v in proxmox_virtual_environment_vm.win11_cbc :
    k => v.vm_id
  }
}

output "vm_ipv4" {
  value = {
    for k, v in proxmox_virtual_environment_vm.win11_cbc :
    k => try(v.ipv4_addresses[1][0], "Booting - check Proxmox console")
  }
}
