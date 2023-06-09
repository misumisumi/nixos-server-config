# Spawns the given amount of machines,
# using the given base image as their root disk,
# attached to the same network.

terraform {
  required_providers {
    lxd = {
      source = "terraform-lxd/lxd"
    }
  }
}

locals {
  mkvolumes = [for device in flatten(var.nodes[*].devices[*]) :
    device.type == "disk" && contains(keys(device.properties), "pool") ? {
      name         = device.properties.source
      pool         = device.properties.pool
      content_type = device.content_type
      } : {
      name         = null
      pool         = null
      content_type = null
    }
  ]
}

module "volume" {
  source  = "../volume"
  volumes = local.mkvolumes
}

resource "lxd_profile" "profile" {
  name = "profile_${var.name}"

  config = {
    # "security.privileged" = true
    "security.nesting"                          = true
    "security.syscalls.intercept.mount.allowed" = "ext4"
    "security.syscalls.intercept.mount"         = true
    "boot.autostart"                            = true
    "limits.cpu"                                = tonumber(var.node_rd.cpu)
    "limits.memory"                             = var.node_rd.memory
    "raw.lxc"                                   = <<EOT
        lxc.apparmor.profile = unconfined
        lxc.cap.drop = ""
        lxc.cgroup.devices.allow = a
    EOT
  }

  device {
    type = "disk"
    name = "root"

    properties = {
      pool = "default"
      path = "/"
      size = var.node_rd.root_size
    }
  }
  device {
    type = "unix-block"
    name = "loop0"
    properties = {
      path = "/dev/loop0"
    }
  }
}

resource "lxd_container" "node" {
  for_each = { for i in var.nodes : i.name => i }
  target   = contains(keys(each.value), "target") ? each.value.target : null

  name = each.value.name
  type = each.value.type

  image = "nixos/lxc-${each.value.type}"

  profiles = ["${lxd_profile.profile.name}"]

  device {
    name = "eth0"
    type = "nic"

    properties = {
      nictype        = "bridged"
      parent         = var.node_rd.nic_parent
      "ipv4.address" = contains(keys(each.value), "ip_address") && terraform.workspace != "product" ? each.value.ip_address : null
    }
  }
  dynamic "device" {
    for_each = each.value.devices
    content {
      type       = device.value.type
      name       = device.value.name
      properties = device.value.properties
    }
  }
  depends_on = [module.volume, lxd_profile.profile]
}