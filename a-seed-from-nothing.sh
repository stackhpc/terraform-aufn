#!/bin/bash

# Exit on error
set -e

# Reset SECONDS
SECONDS=0

# Registry IP
registry_ip=$1
echo "[INFO] Given docker registry IP: $registry_ip"

# Clone Kayobe.
[[ -d kayobe ]] || git clone https://git.openstack.org/openstack/kayobe.git -b stable/train
cd kayobe

# Clone this Kayobe configuration.
mkdir -p config/src
cd config/src/
[[ -d kayobe-config ]] || git clone https://github.com/stackhpc/a-universe-from-nothing.git -b stable/train kayobe-config

# Set default registry name to the one we just created
sed -i.bak 's/^docker_registry.*/docker_registry: '$registry_ip':4000/' kayobe-config/etc/kayobe/docker.yml

# Configure host networking (bridge, routes & firewall)
./kayobe-config/configure-local-networking.sh

# Install kayobe.
cd ~/kayobe
./dev/install.sh

# Deploy hypervisor services.
./dev/seed-hypervisor-deploy.sh

# Deploy a seed VM.
# NOTE: This will work the first time because the packet configuration uses a
# custom docker registry.
if ! ./dev/seed-deploy.sh; then
    # Pull, retag images, then push to our local registry.
    ./config/src/kayobe-config/pull-retag-push-images.sh train

    # Deploy a seed VM. Should work this time.
    ./dev/seed-deploy.sh
fi

# Clone the Tenks repository.
[[ -d tenks ]] || git clone https://git.openstack.org/openstack/tenks.git -b stable/1.0

# Install Open vSwitch for Tenks.
sudo yum install -y centos-release-openstack-train
sudo yum install -y openvswitch
sudo systemctl enable openvswitch
sudo systemctl start openvswitch

# Duration
duration=$SECONDS
echo "[INFO] $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
