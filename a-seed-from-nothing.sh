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

# Clone Kayobe.
[[ -d kayobe ]] || git clone https://opendev.org/openstack/kayobe.git -b stable/train
cd kayobe

# Clone the Tenks repository.
[[ -d tenks ]] || git clone https://opendev.org/openstack/tenks.git

# Clone this Kayobe configuration.
mkdir -p config/src
cd config/src/
[[ -d kayobe-config ]] || git clone https://github.com/stackhpc/a-universe-from-nothing.git -b stable/train-centos8 kayobe-config

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
    ./config/src/kayobe-config/pull-retag-push-images.sh train-centos8

    # Deploy a seed VM. Should work this time.
    ./dev/seed-deploy.sh
fi

# Duration
duration=$SECONDS
echo "[INFO] $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
