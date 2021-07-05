resource "openstack_compute_keypair_v2" "ufn_lab_key" {
  name       = "ufn_lab_key"
  public_key = tls_private_key.default.public_key_openssh
}


resource "openstack_compute_instance_v2" "bastion" {
  name            = "${var.deploy_prefix}-bastion"
  image_name      = var.image_name
  flavor_name     = var.bastion_flavor
  key_pair        = openstack_compute_keypair_v2.ufn_lab_key.name
  security_groups = ["default"]

  network {
    name = var.lab_net_ipv6
  }

  network {
    name = var.lab_net_ipv4
  }
}

resource "openstack_compute_instance_v2" "registry" {
  name            = "${var.deploy_prefix}-registry"
  image_name      = var.image_name
  flavor_name     = var.registry_flavor
  key_pair        = openstack_compute_keypair_v2.ufn_lab_key.name
  security_groups = ["default"]

  network {
    name = var.lab_net_ipv4
  }
}

resource "null_resource" "registry" {
  connection {
    bastion_user        = "centos"
    bastion_private_key = tls_private_key.default.private_key_pem
    bastion_host        = openstack_compute_instance_v2.bastion.access_ip_v6
    user                = "centos"
    private_key         = tls_private_key.default.private_key_pem
    agent               = false
    timeout             = "300s"
    host                = openstack_compute_instance_v2.registry.access_ip_v4
  }

  triggers = {
    pull_retag_push_images = file("pull-retag-push-images.sh")
  }

  provisioner "file" {
    content     = self.triggers.pull_retag_push_images
    destination = "/tmp/pull-retag-push-images.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash /tmp/pull-retag-push-images.sh > pull-retag-push-images.out",
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
    name = var.lab_net_ipv4
  }

  depends_on = [openstack_compute_keypair_v2.ufn_lab_key]
}

resource "null_resource" "lab" {
  count = var.lab_count

  connection {
    bastion_user        = "centos"
    bastion_private_key = tls_private_key.default.private_key_pem
    bastion_host        = openstack_compute_instance_v2.bastion.access_ip_v6
    user                = "centos"
    private_key         = tls_private_key.default.private_key_pem
    agent               = false
    timeout             = "300s"
    host                = openstack_compute_instance_v2.lab[count.index].access_ip_v4
  }


  triggers = {
    registry_ip = openstack_compute_instance_v2.registry.access_ip_v4
    host_id     = openstack_compute_instance_v2.lab[count.index].id
  }

  provisioner "remote-exec" {
    script = "setup-user.sh"
  }

  provisioner "file" {
    source      = "a-seed-from-nothing.sh"
    destination = "/tmp/a-seed-from-nothing.sh"
  }

  provisioner "file" {
    source      = "a-universe-from-seed.sh"
    destination = "/tmp/a-universe-from-seed.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo install /tmp/a-seed-from-nothing.sh /home/lab",
      "sudo install /tmp/a-universe-from-seed.sh /home/lab",
      "sudo usermod -p `echo ${self.triggers.host_id} | openssl passwd -1 -stdin` lab",
      "sudo yum install -y git tmux",
      "# sudo -u lab /home/lab/a-seed-from-nothing.sh ${self.triggers.registry_ip} | sudo -u lab tee -a /home/lab/a-seed-from-nothing.out",
    ]
  }
}
