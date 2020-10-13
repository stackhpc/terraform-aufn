#!/bin/bash

# Reset SECONDS
SECONDS=0

# Registry IP
registry_ip=$1
echo "[INFO] Given docker registry IP: $registry_ip"

# Disable the firewall.
sudo systemctl is-enabled firewalld && sudo systemctl stop firewalld && sudo systemctl disable firewalld

# Disable SELinux.
sudo setenforce 0

# Exit on error
# NOTE(priteau): Need to be set here as setenforce can return a non-zero exit
# code
set -e

# Work around connectivity issues seen while configuring this node as seed
# hypervisor with Kayobe
sudo dnf install -y network-scripts
sudo rm -f /etc/sysconfig/network-scripts/ifcfg-ens3
cat <<EOF | sudo tee /etc/sysctl.d/70-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sudo sysctl --load /etc/sysctl.d/70-ipv6.conf
sudo systemctl is-active NetworkManager && (sudo systemctl disable NetworkManager; sudo systemctl enable network; sudo ip link del dev bond0; sudo systemctl stop NetworkManager; sudo systemctl start network)

# Clone Kayobe.
[[ -d kayobe ]] || git clone https://opendev.org/openstack/kayobe.git -b master
cd kayobe

# Clone the Tenks repository.
[[ -d tenks ]] || git clone https://opendev.org/openstack/tenks.git

# Clone this Kayobe configuration.
mkdir -p config/src
cd config/src/
[[ -d kayobe-config ]] || git clone https://github.com/stackhpc/a-universe-from-nothing.git -b master kayobe-config

# Set default registry name to the one we just created
sed -i.bak 's/^docker_registry.*/docker_registry: '$registry_ip':4000/' kayobe-config/etc/kayobe/docker.yml

# Configure host networking (bridge, routes & firewall)
./kayobe-config/configure-local-networking.sh

# Install kayobe.
cd ~/kayobe
./dev/install-dev.sh

# Deploy hypervisor services.
./dev/seed-hypervisor-deploy.sh

# Deploy a seed VM.
# NOTE: This will work the first time because the packet configuration uses a
# custom docker registry.
if ! ./dev/seed-deploy.sh; then
    # Pull, retag images, then push to our local registry.
    ./config/src/kayobe-config/pull-retag-push-images.sh master

    # Deploy a seed VM. Should work this time.
    ./dev/seed-deploy.sh
fi

# Duration
duration=$SECONDS
echo "[INFO] $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
