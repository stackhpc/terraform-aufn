locals {
  template = {
    bastion  = tomap({ ip = trim(openstack_compute_instance_v2.bastion.access_ip_v4, "[]"), name = openstack_compute_instance_v2.bastion.name })
    registry = tomap({ ip = openstack_compute_instance_v2.registry.access_ip_v4, name = openstack_compute_instance_v2.registry.name })
    labs     = tomap({ names = openstack_compute_instance_v2.lab.*.name, ips = openstack_compute_instance_v2.lab.*.access_ip_v4 })
  }
}

resource "local_file" "ssh_config" {
  content  = templatefile("ssh-config.tpl", local.template)
  filename = pathexpand("~/.ssh/config.${var.lab_prefix}")
}
