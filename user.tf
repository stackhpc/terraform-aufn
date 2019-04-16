resource "null_resource" "user" {

  count         = "${var.lab_count}"

  connection {
    user        = "root"
    private_key = "${tls_private_key.default.private_key_pem}"
    agent       = false
    timeout     = "30s"
    host        = "${element(packet_device.lab.*.access_public_ipv4,count.index)}"
  }

  provisioner "remote-exec" {
    script = "setup-user.sh"
  }
}
