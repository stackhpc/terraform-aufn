output "registry_ip" {
  value = var.lab_count > 0 ? openstack_compute_instance_v2.registry.access_ip_v4 : ""
}

output "lab_ips" {
  value = join("", formatlist("\n    ssh -o ProxyCommand='ssh -W %%h:%%p centos@%s' lab@%s #password: %s",
    trim(openstack_compute_instance_v2.bastion.access_ip_v6, "[]"),
    openstack_compute_instance_v2.lab.*.access_ip_v4,
  openstack_compute_instance_v2.lab.*.id))
}
