resource "openstack_compute_keypair_v2" "ufn_lab_key" {
  name       = "ufn_lab_key"
  public_key = tls_private_key.default.public_key_openssh
}

resource "openstack_compute_instance_v2" "registry" {

  name            = "${var.deploy_prefix}-registry"
  image_name      = var.image_name
  flavor_name     = var.registry_flavor
  key_pair        = openstack_compute_keypair_v2.ufn_lab_key.name
  security_groups = ["default"]

  network {
    name = var.lab_net
  }

  count            = var.lab_count > 0 ? 1 : 0

  connection {
    user        = "centos"
    private_key = tls_private_key.default.private_key_pem
    agent       = false
    timeout     = "300s"
    host        = self.access_ip_v4
  }

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

resource "openstack_compute_instance_v2" "lab" {

  count           = var.lab_count
  name            = format("%s-lab-%02d", var.deploy_prefix, count.index)
  image_name      = var.image_name
  flavor_name     = var.lab_flavor
  key_pair        = openstack_compute_keypair_v2.ufn_lab_key.name
  security_groups = ["default"]

  network {
    name = var.lab_net
  }

  depends_on = [openstack_compute_keypair_v2.ufn_lab_key]

  connection {
    user        = "centos"
    private_key = tls_private_key.default.private_key_pem
    agent       = false
    timeout     = "300s"
    host        = self.access_ip_v4
  }

  provisioner "remote-exec" {
    script = "setup-user.sh"
  }

  provisioner "file" {
    source      = "a-seed-from-nothing.sh"
    destination = "a-seed-from-nothing.sh"
  }

  provisioner "file" {
    source      = "a-universe-from-seed.sh"
    destination = "a-universe-from-seed.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo install /home/centos/a-seed-from-nothing.sh /home/lab",
      "sudo install /home/centos/a-universe-from-seed.sh /home/lab",
      "sudo usermod -p `echo ${self.id} | openssl passwd -1 -stdin` lab",
      "sudo yum install -y git tmux",
      "sudo -u lab /home/lab/a-seed-from-nothing.sh ${openstack_compute_instance_v2.registry[0].access_ip_v4} | sudo -u lab tee -a /home/lab/a-seed-from-nothing.out",
    ]
  }
}
