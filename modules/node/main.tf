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

module "network" {
  count  = terraform.workspace == "product" ? 0 : 1
  source = "../network"
}

resource "lxd_profile" "profile" {
  name = "profile_${var.name}"

  config = {
    "boot.autostart" = true
    "limits.cpu"     = tonumber(var.node_rd.cpu)
    "limits.memory"  = var.node_rd.memory
  }

  device {
    type = "disk"
    name = "root"

    properties = {
      pool = "pool_${var.name}"
      path = "/"
    }
  }
}

resource "lxd_container" "node" {
  for_each = { for i in var.nodes : i.name => i }
  target   = contains(keys(each.value), "target") ? each.value.target : null

  name = each.value.name

  image = "nixos"

  profiles = ["${lxd_profile.profile.name}"]

  device {
    name = "eth0"
    type = "nic"

    properties = {
      nictype        = "bridged"
      parent         = terraform.workspace == "product" ? var.node_rd.nic_parent : module.network[0].name
      "ipv4.address" = contains(keys(each.value), "ip_address") ? each.value.ip_address : null
    }
  }
}
