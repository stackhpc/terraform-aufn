
echo "RESUME=non" > /etc/initramfs-tools/conf.d/noresume.conf

apt-get install libvirt-clients libvirt-daemon-system qemu-kvm -y

systemctl enable libvirtd.service
systemctl start libvirtd.service

usermod -a -G libvirt $(whoami)

newgrp libvirt

curl -o /tmp/docker-machine-driver-kvm2 -L https://storage.googleapis.com/minikube/releases/latest/docker-machine-driver-kvm2
install /tmp/docker-machine-driver-kvm2 /usr/local/bin/
