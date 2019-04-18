output "Registry IP" {
  value = "${packet_device.registry.access_public_ipv4}"
}

output "Lab IPs" {
  value = "${packet_device.lab.*.access_public_ipv4}"
}