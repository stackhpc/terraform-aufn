#!/bin/bash

# Exit on error
set -e

# Registry IP
registry_ip=$1
echo "Given docker registry IP: $registry_ip"

# Reset SECONDS
SECONDS=0

# Clone Kayobe.
git clone https://git.openstack.org/openstack/kayobe.git -b stable/rocky
cd kayobe

# Clone this Kayobe configuration.
mkdir -p config/src
cd config/src/
git clone https://github.com/stackhpc/a-universe-from-nothing.git kayobe-config

# Set default registry name to the one we just created
sed -i.bak 's/^docker_registry.*/docker_registry: '$registry_ip'/' kayobe-config/etc/kayobe/docker.yml

# Default interface is called bond0 on packet
sed -i.bak 's/eth0/bond0/g' kayobe-config/configure-local-networking.sh

./kayobe-config/configure-local-networking.sh

# Install kayobe.
cd ~/kayobe
./dev/install.sh

# Deploy hypervisor services.
./dev/seed-hypervisor-deploy.sh

# Deploy a seed VM.
# NOTE: This will work the first time because the packet configuration uses a
# custom docker registry.
./dev/seed-deploy.sh

# Pull, retag images, then push to our local registry.
# ./config/src/kayobe-config/pull-retag-push-images.sh

# Deploy a seed VM. Should work this time.
# ./dev/seed-deploy.sh

# FIXME: There is an issue with Bifrost which does not restrict the version
# of proliantutils it installs.
ssh stack@192.168.33.5 sudo docker exec bifrost_deploy pip install proliantutils==2.7.0
ssh stack@192.168.33.5 sudo docker exec bifrost_deploy systemctl restart ironic-conductor

# Clone the Tenks repository.
git clone https://git.openstack.org/openstack/tenks.git

# Duration
duration=$SECONDS
echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."

# Open a shell session and wait 
/bin/bash

