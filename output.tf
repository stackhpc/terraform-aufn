output "labs" {
  value = join("\n", formatlist("ssh %s # %s", openstack_compute_instance_v2.lab.*.name, openstack_compute_instance_v2.lab.*.id))
}

output "registry" {
  value = "ssh ${openstack_compute_instance_v2.registry.name}"
}
