output "Lab IPs" {
  value = "${packet_device.lab.*.access_public_ipv4}"
}
