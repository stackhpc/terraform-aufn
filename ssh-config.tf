locals {
  template = {
    bastion  = var.create_bastion ? tomap({ ip = openstack_compute_floatingip_associate_v2.bastion[0].floating_ip, name = openstack_compute_instance_v2.bastion[0].name }) : ({ip="",name=""})
    registry = tomap({ ip = openstack_compute_instance_v2.registry.access_ip_v4, name = openstack_compute_instance_v2.registry.name })
    labs     = tomap({ names = openstack_compute_instance_v2.lab.*.name, ips = openstack_compute_instance_v2.lab.*.access_ip_v4 })
  }
}
resource "local_file" "ssh_config" {
  content  = templatefile("ssh-config.tpl", local.template)
  filename = pathexpand("~/.ssh/config.${var.lab_prefix}")
}