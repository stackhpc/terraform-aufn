output "registry_ip" {
  value = var.lab_count > 0 ? openstack_compute_instance_v2.registry[0].access_ip_v4 : ""
}

output "lab_ips" {
  value = join("", formatlist("\n    ssh -o PreferredAuthentications=password lab@%s #password: %s",
      openstack_compute_instance_v2.lab.*.access_ip_v4,
      openstack_compute_instance_v2.lab.*.id))
}

output "ansible_inventory" {
  value = <<EOT
.
    [lab]
${join("\n",
  formatlist("    %s ansible_host=%s ansible_user=lab",
    openstack_compute_instance_v2.lab.*.name,
    openstack_compute_instance_v2.lab.*.access_ip_v4))
 }
EOT
}
