#!/bin/bash

# Reset SECONDS
SECONDS=0

# Registry IP
[[ -z "$1" ]] && echo "Usage ./a-seed-from-nothing.sh <registry IP>" && exit 1
registry_ip=$1
echo "[INFO] Given docker registry IP: $registry_ip"

# Disable the firewall.
rpm -q firewalld && sudo systemctl is-enabled firewalld && sudo systemctl stop firewalld && sudo systemctl disable firewalld

# Disable SELinux.
sudo setenforce 0

# Work around connectivity issues seen while configuring this node as seed
# hypervisor with Kayobe
sudo dnf install -y network-scripts
sudo rm -f /etc/sysconfig/network-scripts/ifcfg-ens3*
cat <<EOF | sudo tee /etc/sysctl.d/70-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sudo sysctl --load /etc/sysctl.d/70-ipv6.conf
sudo systemctl is-active NetworkManager && (sudo systemctl disable NetworkManager; sudo systemctl stop NetworkManager)
sudo systemctl is-active network || (sudo systemctl enable network; sudo pkill dhclient; sudo systemctl start network)

# Exit on error
# NOTE(priteau): Need to be set here as setenforce can return a non-zero exit code
# NOTE(brtknr): pkill dhclient may exit 1 so set -e from here
set -e

# Clone Kayobe.
cd $HOME
[[ -d kayobe ]] || git clone https://opendev.org/openstack/kayobe.git -b stable/wallaby
cd kayobe

# Bump the provisioning time - it can be lengthy on virtualised storage
sed -i.bak 's%^[# ]*wait_active_timeout:.*%    wait_active_timeout: 5000%' ~/kayobe/ansible/overcloud-provision.yml

# Clone the Tenks repository.
[[ -d tenks ]] || git clone https://opendev.org/openstack/tenks.git

# Clone this Kayobe configuration.
mkdir -p config/src
cd config/src/
#[[ -d kayobe-config ]] || git clone https://github.com/stackhpc/a-universe-from-nothing.git -b stable/wallaby kayobe-config
[[ -d kayobe-config ]] || git clone https://github.com/stackhpc/a-universe-from-nothing.git -b nesi-wallaby kayobe-config

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
# NOTE: This should work the first time because the packet configuration uses a
# custom docker registry.  However, there are sometimes issues with Docker starting up on the seed (FIXME)
if ! ./dev/seed-deploy.sh; then
    # Deploy a seed VM. Should work this time.
    ./dev/seed-deploy.sh
fi

# Duration
duration=$SECONDS
echo "[INFO] $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
