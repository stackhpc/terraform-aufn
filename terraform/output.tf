output "Lab IPs" {
  value = "${packet_device.lab.*.access_public_ipv4}"
}

output "Key" {
  value = "${tls_private_key.lab.private_key_pem}"
}
