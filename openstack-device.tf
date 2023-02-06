resource "openstack_compute_keypair_v2" "ufn_lab_key" {
  name       = "ufn_lab_key"
  public_key = tls_private_key.default.public_key_openssh
}

resource "openstack_compute_instance_v2" "bastion" {
  count = var.create_bastion ? 1 : 0
  name            = "${var.lab_prefix}-bastion"
  image_name      = var.image_name
  flavor_name     = var.bastion_flavor
  key_pair        = openstack_compute_keypair_v2.ufn_lab_key.name
  security_groups = ["default"]
  network {
    name = var.lab_net_ipv4
  }
  timeouts {
    create = "30m"
  }
}

resource "openstack_compute_floatingip_associate_v2" "bastion" {
  count = var.create_bastion ? 1 : 0
  floating_ip = var.bastion_floating_ip
  instance_id = openstack_compute_instance_v2.bastion[0].id
}

resource "null_resource" "bastion" {
  count = var.create_bastion ? 1 : 0
  connection {
    host        = openstack_compute_floatingip_associate_v2.bastion[0].floating_ip
    user        = "centos"
    private_key = tls_private_key.default.private_key_pem
    agent       = false
    timeout     = "300s"
  }

  triggers = {
    ssh_config  = templatefile("ssh-config.tpl", local.template)
  }

  provisioner "file" {
    content     = self.triggers.ssh_config
    destination = "/tmp/ssh_config"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh; chmod 0700 ~/.ssh; cp /tmp/ssh_config ~/.ssh/config",
    ]
  }
}

# Boot instance with volume attached for Docker Registry
resource "openstack_compute_instance_v2" "registry" {
  name            = "${var.lab_prefix}-registry"
  flavor_name     = var.registry_flavor
  key_pair        = openstack_compute_keypair_v2.ufn_lab_key.name
  security_groups = ["default"]

  block_device {
    uuid                  = var.image_id
    source_type           = "image"
    volume_size           = var.registry_data_vol
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }

  network {
    name = var.lab_net_ipv4
  }
}

resource "openstack_compute_floatingip_v2" "registry" {
  count = var.allocate_floating_ips ? 1 : 0
  pool = "external"
}

resource "openstack_compute_floatingip_associate_v2" "registry" {
  count = var.allocate_floating_ips ? 1 : 0
  floating_ip = openstack_compute_floatingip_v2.registry[count.index].address
  instance_id = openstack_compute_instance_v2.registry.id
}

resource "null_resource" "registry" {
  connection {
    user                = var.image_user
    private_key         = tls_private_key.default.private_key_pem
    agent               = false
    timeout             = "300s"
    host                = var.allocate_floating_ips ? openstack_compute_floatingip_associate_v2.registry[0].floating_ip : openstack_compute_instance_v2.registry.network.0.fixed_ip_v4
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
  name            = format("%s-lab-%02d", var.lab_prefix, count.index)
  image_name      = var.image_name
  flavor_name     = var.lab_flavor
  key_pair        = openstack_compute_keypair_v2.ufn_lab_key.name

  dynamic "block_device" {
    for_each = var.boot_labs_from_volume ? [1] : []
    content {
      uuid                  = var.image_id
      source_type           = "image"
      volume_size           = var.lab_data_vol
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    name = var.lab_net_ipv4
  }

  depends_on = [openstack_compute_keypair_v2.ufn_lab_key, null_resource.registry]
}

resource "openstack_compute_floatingip_v2" "lab" {
  count = var.allocate_floating_ips ? var.lab_count : 0
  pool = "external"
}

resource "openstack_compute_floatingip_associate_v2" "lab" {
  count = var.allocate_floating_ips ? var.lab_count : 0

  floating_ip = openstack_compute_floatingip_v2.lab[count.index].address
  instance_id = openstack_compute_instance_v2.lab[count.index].id
}

resource "null_resource" "lab" {
  count = var.lab_count

  connection {
    user                = var.image_user
    private_key         = tls_private_key.default.private_key_pem
    agent               = false
    timeout             = "300s"
    host                = var.allocate_floating_ips ? openstack_compute_floatingip_associate_v2.lab[count.index].floating_ip : openstack_compute_instance_v2.lab[count.index].network.0.fixed_ip_v4
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
