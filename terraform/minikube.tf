resource "null_resource" "minikube" {

  count         = "${var.lab_count}"

  connection {
    user        = "root"
    private_key = "${tls_private_key.default.private_key_pem}"
    agent       = false
    timeout     = "30s"
    host        = "${element(packet_device.lab.*.access_public_ipv4,count.index)}"
  }

  provisioner "file" {
    source      = "add-libvirt-group.sh"
    destination = "add-libvirt-group.sh"
  }


  provisioner "file" {
    source      = "install-kubectl.sh"
    destination = "install-kubectl.sh"
  }

  provisioner "file" {
    source      = "install-kvm.sh"
    destination = "install-kvm.sh"
  }

  provisioner "file" {
    source      = "install-kvm-driver.sh"
    destination = "install-kvm-driver.sh"
  }

  provisioner "file" {
    source      = "install-minikube.sh"
    destination = "install-minikube.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash add-libvirt-group.sh > add-libvirt-group.sh",
      "bash install-kubectl.sh > install-kubectl.out",
      "bash install-kvm-driver.sh > install-kvm-driver.out",
      "bash install-minikube.sh > install-minikube.out",
      "bash install-kvm.sh > install-kvm.out",
    ]
  }
}
