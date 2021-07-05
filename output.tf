output "registry_ip" {
  value = var.lab_count > 0 ? openstack_compute_instance_v2.registry.access_ip_v4 : ""
}

output "lab_ips" {
  value = join("", formatlist("\n    ssh -J centos@${openstack_compute_instance_v2.bastion.access_ip_v6} -o PreferredAuthentications=password lab@%s #password: %s",
    openstack_compute_instance_v2.lab.*.access_ip_v4,
  openstack_compute_instance_v2.lab.*.id))
}
