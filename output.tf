output "Registry-IP" {
  value = "${packet_device.registry.access_public_ipv4}"
}

output "Alternative-Registry-IP" {
  value = "${packet_device.registry_alt.access_public_ipv4}"
}

output "Lab-IPs" {
  value = "${
    join("", formatlist(
      "\nssh -o PreferredAuthentications=password lab@%s",
      concat(packet_device.lab_alt.*.access_public_ipv4, packet_device.lab.*.access_public_ipv4)
  ))}"
}

output "Ansible-Inventory" {
  value = "${
    join("", formatlist(
      "\n%s ansible_host=%s ansible_user=root",
      concat(packet_device.lab_alt.*.hostname, packet_device.lab.*.hostname),
      concat(packet_device.lab_alt.*.access_public_ipv4, packet_device.lab.*.access_public_ipv4)
  ))}"
}
