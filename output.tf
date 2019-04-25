output "Registry IP" {
  value = "${packet_device.registry.access_public_ipv4}"
}

output "Alternative Registry IP" {
  value = "${packet_device.registry_alt.access_public_ipv4}"
}

output "Lab IPs" {
  value = "${packet_device.lab.*.access_public_ipv4}"
}

output "Alternative Lab IPs" {
  value = "${packet_device.lab_alt.*.access_public_ipv4}"
}
