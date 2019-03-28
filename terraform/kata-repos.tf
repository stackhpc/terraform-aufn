resource "null_resource" "kata-repo" {

  depends_on    = ["null_resource.minikube" ]

  count         = "${var.lab_count}"

  connection {
    user        = "root"
    private_key = "${tls_private_key.default.private_key_pem}"
    agent       = false
    timeout     = "30s"
    host        = "${element(packet_device.lab.*.access_public_ipv4,count.index)}"
  }

  provisioner "file" {
    source      = "kata-repos.sh" 
    destination = "kata-repos.sh" 
  }

  provisioner "remote-exec" {
    inline = [
      "bash kata-repos.sh > kata-repos.out",
    ]
  }
}
