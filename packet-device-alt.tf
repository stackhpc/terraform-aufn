resource "packet_device" "registry_alt" {
  depends_on = [packet_ssh_key.default]

  count            = var.lab_count_alt > 0 ? 1 : 0
  hostname         = "${var.deploy_prefix}-registry-alt"
  operating_system = var.operating_system
  plan             = var.plan

  connection {
    user        = "root"
    private_key = tls_private_key.default.private_key_pem
    agent       = false
    timeout     = "30s"
    host        = self.access_public_ipv4
  }
  facilities    = [var.packet_facility_alt]
  project_id    = var.packet_project_id
  billing_cycle = "hourly"

  provisioner "file" {
    source      = "pull-retag-push-images.sh"
    destination = "pull-retag-push-images.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash pull-retag-push-images.sh > pull-retag-push-images.out",
    ]
  }
}

resource "packet_device" "lab_alt" {

  depends_on = [packet_ssh_key.default]

  count            = var.lab_count_alt
  hostname         = format("%s-lab-alt-%02d", var.deploy_prefix, count.index)
  operating_system = var.operating_system
  plan             = var.plan

  connection {
    user        = "root"
    private_key = tls_private_key.default.private_key_pem
    agent       = false
    timeout     = "30s"
    host        = self.access_public_ipv4
  }

  facilities    = [var.packet_facility_alt]
  project_id    = var.packet_project_id
  billing_cycle = "hourly"

  provisioner "remote-exec" {
    script = "setup-user.sh"
  }

  provisioner "file" {
    source      = "a-seed-from-nothing.sh"
    destination = "/home/lab/a-seed-from-nothing.sh"
  }

  provisioner "file" {
    source      = "a-universe-from-seed.sh"
    destination = "/home/lab/a-universe-from-seed.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "usermod -p `echo ${self.id} | openssl passwd -1 -stdin` lab",
      "yum install -y git tmux",
      "su -c 'bash a-seed-from-nothing.sh ${packet_device.registry_alt[0].access_public_ipv4} > a-seed-from-nothing.out' - lab",
    ]
  }
}
