output "registry_ip" {
  value = var.lab_count > 0 ? packet_device.registry[0].access_public_ipv4 : ""
}

output "registry_ip_alt" {
  value = var.lab_count_alt > 0 ? packet_device.registry_alt[0].access_public_ipv4 : ""
}

output "lab_ips" {
  value = join("", formatlist("\n    ssh -o PreferredAuthentications=password lab@%s #password: %s",
      concat(packet_device.lab_alt.*.access_public_ipv4, packet_device.lab.*.access_public_ipv4),
      concat(packet_device.lab_alt.*.id, packet_device.lab.*.id)
  ))
}

output "ansible_inventory" {
  value = <<EOT
.
    [lab]
${join("\n",
  formatlist("    %s ansible_host=%s ansible_user=lab",
    concat(packet_device.lab_alt.*.hostname, packet_device.lab.*.hostname),
    concat(packet_device.lab_alt.*.access_public_ipv4, packet_device.lab.*.access_public_ipv4)
))}
EOT
}
