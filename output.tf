output "labs" {
  value = join("\n", formatlist("ssh %s %s # %s #", openstack_compute_instance_v2.lab.*.name, openstack_compute_instance_v2.lab.*.access_ip_v4, openstack_compute_instance_v2.lab.*.id))
}

output "registry" {
  value = "ssh ${openstack_compute_instance_v2.registry.name}"
}

output "registry_ip" {
  value = join("\n", formatlist("%s", openstack_compute_instance_v2.registry.*.access_ip_v4))
}