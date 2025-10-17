resource "openstack_compute_keypair_v2" "ufn_lab_key" {
  name       = "${var.lab_prefix}_lab_key"
  public_key = tls_private_key.default.public_key_openssh
}

data "openstack_networking_network_v2" "lab_network" {
  name = var.lab_net_ipv4
}

data "openstack_networking_secgroup_v2" "default_secgroup" {
  name = "default"
}

resource "openstack_networking_port_v2" "bastion_port" {
  name           = format("%s-bastion", var.lab_prefix)
  admin_state_up = true

  network_id = data.openstack_networking_network_v2.lab_network.id

  security_group_ids = [
    data.openstack_networking_secgroup_v2.default_secgroup.id
  ]
}

resource "openstack_compute_instance_v2" "bastion" {
  count = var.create_bastion ? 1 : 0
  name            = "${var.lab_prefix}-bastion"
  image_name      = var.image_name
  flavor_name     = var.bastion_flavor
  key_pair        = openstack_compute_keypair_v2.ufn_lab_key.name
  network {
    port = openstack_networking_port_v2.bastion_port.id
  }
  timeouts {
    create = "30m"
  }
}

resource "openstack_networking_floatingip_associate_v2" "bastion" {
  count = var.create_bastion ? 1 : 0
  floating_ip = var.bastion_floating_ip
  port_id = openstack_networking_port_v2.bastion_port.id
}

resource "null_resource" "bastion" {
  count = var.create_bastion ? 1 : 0
  connection {
    host        = openstack_networking_floatingip_associate_v2.bastion[0].floating_ip
    user        = var.image_user
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

resource "openstack_networking_port_v2" "registry_port" {
  name           = format("%s-registry", var.lab_prefix)
  admin_state_up = "true"

  network_id = data.openstack_networking_network_v2.lab_network.id

  security_group_ids = [
    data.openstack_networking_secgroup_v2.default_secgroup.id
  ]
}

# Boot instance with volume attached for Docker Registry
resource "openstack_compute_instance_v2" "registry" {
  name            = "${var.lab_prefix}-registry"
  flavor_name     = var.registry_flavor
  key_pair        = openstack_compute_keypair_v2.ufn_lab_key.name

  block_device {
    uuid                  = var.image_id
    source_type           = "image"
    volume_size           = var.registry_data_vol
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }

  network {
    port = openstack_networking_port_v2.registry_port.id
  }
}

resource "openstack_networking_floatingip_v2" "registry" {
  count = var.allocate_floating_ips ? 1 : 0
  pool = var.floating_ip_external_net
}

resource "openstack_networking_floatingip_associate_v2" "registry" {
  count = var.allocate_floating_ips ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.registry[count.index].address
  port_id = openstack_networking_port_v2.registry_port.id
}

resource "null_resource" "registry" {
  connection {
    bastion_user        = var.create_bastion ? var.image_user : null
    bastion_private_key = var.create_bastion ? tls_private_key.default.private_key_pem : null
    bastion_host        = var.create_bastion ? openstack_networking_floatingip_associate_v2.bastion[0].floating_ip : null
    user                = var.image_user
    private_key         = tls_private_key.default.private_key_pem
    agent               = false
    timeout             = "300s"
    host                = var.allocate_floating_ips ? openstack_networking_floatingip_associate_v2.registry[0].floating_ip : openstack_compute_instance_v2.registry.network.0.fixed_ip_v4
  }

  triggers = {
    pull_retag_push_images = file("${path.module}/pull-retag-push-images.sh")
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

resource "openstack_networking_secgroup_v2" "AUFN" {
  name        = "${var.lab_prefix}-lab-rules"
  description = "Access rules for AUFN lab deployment"
}

locals {
  aufn_tcp_ports = {
    ssh          = 22
    http         = 80
    grafana      = 3000
    opensearch   = 5601
    prometheus   = 9091
    alertmanager = 9093
  }
}

resource "openstack_networking_secgroup_rule_v2" "aufn_rules" {
  for_each = local.aufn_tcp_ports

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = each.value
  port_range_max    = each.value
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.AUFN.id
}

data "openstack_dns_zone_v2" "lab_zone" {
  count = var.dns_zone_name != null ? 1 : 0
  name  = var.dns_zone_name
}

resource "openstack_dns_recordset_v2" "lab_dns" {
  count       = var.dns_zone_name != null ? var.lab_count : 0
  zone_id     = data.openstack_dns_zone_v2.lab_zone[0].id
  name        = format("%s-lab-%02d.%s", var.lab_prefix, count.index, var.dns_zone_name)
  type        = "A"
  ttl         = 300
  records     = [openstack_compute_instance_v2.lab[count.index].network[0].fixed_ip_v4]
}

resource "openstack_networking_port_v2" "lab_port" {
  count          = var.lab_count
  name           = format("%s-lab-%02d", var.lab_prefix, count.index)
  admin_state_up = true

  network_id = data.openstack_networking_network_v2.lab_network.id

  security_group_ids = [
    data.openstack_networking_secgroup_v2.default_secgroup.id,
    openstack_networking_secgroup_v2.AUFN.id
  ]
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
    port = openstack_networking_port_v2.lab_port[count.index].id
  }

  timeouts {
    create = "30m"
  }

  depends_on = [openstack_compute_keypair_v2.ufn_lab_key, null_resource.registry]
}

resource "openstack_networking_floatingip_v2" "lab" {
  count = var.allocate_floating_ips ? var.lab_count : 0
  pool = var.floating_ip_external_net
}

resource "openstack_networking_floatingip_associate_v2" "lab" {
  count = var.allocate_floating_ips ? var.lab_count : 0

  floating_ip = openstack_networking_floatingip_v2.lab[count.index].address
  port_id = openstack_networking_port_v2.lab_port[count.index].id
}

resource "null_resource" "lab" {
  count = var.lab_count

  connection {
    bastion_user        = var.create_bastion ? var.image_user : null
    bastion_private_key = var.create_bastion ? tls_private_key.default.private_key_pem : null
    bastion_host        = var.create_bastion ? openstack_networking_floatingip_associate_v2.bastion[0].floating_ip : null
    user                = var.image_user
    private_key         = tls_private_key.default.private_key_pem
    agent               = false
    timeout             = "300s"
    host                = var.allocate_floating_ips ? openstack_networking_floatingip_associate_v2.lab[count.index].floating_ip : openstack_compute_instance_v2.lab[count.index].network.0.fixed_ip_v4
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
