# Reset SECONDS
SECONDS=0

# Clone Kayobe.
git clone https://git.openstack.org/openstack/kayobe.git -b stable/rocky
cd kayobe

# Clone this Kayobe configuration.
mkdir -p config/src
cd config/src/
git clone https://github.com/stackhpc/a-universe-from-nothing.git -b packet kayobe-config

./kayobe-config/configure-local-networking.sh

# Install kayobe.
cd ~/kayobe
./dev/install.sh

# Deploy hypervisor services.
./dev/seed-hypervisor-deploy.sh

# Deploy a seed VM.
# FIXME: Will fail first time due to missing bifrost image.
./dev/seed-deploy.sh

# Pull, retag images, then push to our local registry.
./config/src/kayobe-config/pull-retag-push-images.sh

# Deploy a seed VM. Should work this time.
./dev/seed-deploy.sh

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

