groups

apt-get install libvirt-clients libvirt-daemon-system qemu-kvm -y 

systemctl enable libvirtd.service
systemctl start libvirtd.service
