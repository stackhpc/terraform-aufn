resource "null_resource" "kayobe" {

  count         = "${var.lab_count}"

  connection {
    user        = "root"
    private_key = "${tls_private_key.default.private_key_pem}"
    agent       = false
    timeout     = "30s"
    host        = "${element(packet_device.lab.*.access_public_ipv4,count.index)}"
  }

  provisioner "file" {
    source      = "install-wrapper.sh"
    destination = "install-wrapper.sh"
  }

  provisioner "file" {
    source      = "install-kayobe.sh"
    destination = "install-kayobe.sh"
  }

  provisioner "file" {
    source      = "configure-kayobe.sh"
    destination = "configure-kayobe.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash install-wrapper.sh > install.out",
    ]
  }
}
