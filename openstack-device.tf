resource "openstack_compute_keypair_v2" "ufn_lab_key" {
  name       = "ufn_lab_key"
  public_key = tls_private_key.default.public_key_openssh
}

resource "openstack_compute_instance_v2" "registry" {
  name            = "${var.lab_prefix}-registry"
  image_name      = var.image_name
  flavor_name     = var.registry_flavor
  key_pair        = openstack_compute_keypair_v2.ufn_lab_key.name
  security_groups = ["default"]

  block_device {
    uuid                  = "938a0642-9a88-4c35-8f08-bdc5c0ab0539"
    source_type           = "image"
    destination_type      = "local"
    boot_index            = 0
    delete_on_termination = true
  }

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.registry.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 1
    delete_on_termination = true
  }

  network {
    name = var.lab_net_ipv4
  }
}

resource "null_resource" "registry" {
  connection {
    user                = "ubuntu"
    private_key         = tls_private_key.default.private_key_pem
    agent               = false
    timeout             = "300s"
    host                = openstack_compute_floatingip_associate_v2.registry.floating_ip
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

resource "openstack_compute_floatingip_v2" "registry" {
  pool = "external"
}

resource "openstack_compute_floatingip_associate_v2" "registry" {
  floating_ip = openstack_compute_floatingip_v2.registry.address
  instance_id = openstack_compute_instance_v2.registry.id
}

resource "openstack_blockstorage_volume_v3" "registry" {
  name = format("%s-registry", var.lab_prefix)
  size = var.registry_data_vol
}

resource "openstack_compute_instance_v2" "lab" {

  count           = var.lab_count
  name            = format("%s-lab-%02d", var.lab_prefix, count.index)
  image_name      = var.image_name
  flavor_name     = var.lab_flavor
  key_pair        = openstack_compute_keypair_v2.ufn_lab_key.name
  security_groups = ["default", "AUFN"]

  network {
    name = var.lab_net_ipv4
  }

  block_device {
    uuid                  = "938a0642-9a88-4c35-8f08-bdc5c0ab0539"
    source_type           = "image"
    destination_type      = "local"
    boot_index            = 0
    delete_on_termination = true
  }

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.lab[count.index].id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 1
    delete_on_termination = true
  }


  depends_on = [openstack_compute_keypair_v2.ufn_lab_key]
}


resource "openstack_compute_floatingip_v2" "lab" {
  count = var.lab_count
  pool = "external"
}

resource "openstack_compute_floatingip_associate_v2" "lab" {
  count = var.lab_count

  floating_ip = openstack_compute_floatingip_v2.lab[count.index].address
  instance_id = openstack_compute_instance_v2.lab[count.index].id
}

resource "openstack_blockstorage_volume_v3" "lab" {
  count = var.lab_count
  name = format("%s-lab-%02d", var.lab_prefix, count.index)
  size = var.lab_data_vol
}

resource "null_resource" "lab" {
  count = var.lab_count

  connection {
    user                = "ubuntu"
    private_key         = tls_private_key.default.private_key_pem
    agent               = false
    timeout             = "300s"
    host                = openstack_compute_floatingip_associate_v2.lab[count.index].floating_ip
  }

  triggers = {
    registry_ip = openstack_compute_instance_v2.registry.access_ip_v4
    host_id     = openstack_compute_instance_v2.lab[count.index].id
    mtu         = 1500
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
      "sudo -u lab /home/lab/a-seed-from-nothing.sh ${self.triggers.registry_ip} | sudo -u lab tee -a /home/lab/a-seed-from-nothing.out",
    ]
  }
}
