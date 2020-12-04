terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    null = {
      source = "hashicorp/null"
    }
    packet = {
      source = "packethost/packet"
    }
    tls = {
      source = "hashicorp/tls"
    }
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
  required_version = ">= 0.13"
}
