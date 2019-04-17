resource "packet_ssh_key" "default" {
  name       = "default"
  public_key = "${tls_private_key.default.public_key_openssh}"
}

resource "packet_device" "registry" {
  depends_on       = ["packet_ssh_key.default"]

  count            = "1"
  hostname         = "registry"
  operating_system = "${var.operating_system}"
  plan             = "${var.plan}"

  connection {
    user        = "root"
    private_key = "${tls_private_key.default.private_key_pem}"
    agent       = false
    timeout     = "30s"
  }
  facilities    = ["${var.packet_facility}"]
  project_id    = "${var.packet_project_id}"
  billing_cycle = "hourly"

  provisioner "file" {
    source      = "pull-retag-push-images.sh"
    destination = "pull-retag-push-images.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "ssh-keygen -A", 
      "bash pull-retag-push-images.sh > pull-retag-push-images.out",
    ]
  }
}

resource "packet_device" "lab" {

  depends_on       = ["packet_ssh_key.default"]

  count            = "${var.lab_count}"
  hostname         = "${format("lab%02d", count.index)}"
  operating_system = "${var.operating_system}"
  plan             = "${var.plan}"

  connection {
    user        = "root"
    private_key = "${tls_private_key.default.private_key_pem}"
    agent       = false
    timeout     = "30s"
  }
  facilities    = ["${var.packet_facility}"]
  project_id    = "${var.packet_project_id}"
  billing_cycle = "hourly"

  provisioner "remote-exec" {
    inline = [
      "ssh-keygen -A", 
    ]
  }
}
