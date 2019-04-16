# Reset SECONDS
SECONDS=0

# Change to kayobe directory
cd kayobe

# Create some 'bare metal' VMs for the controller and compute node.
# NOTE: Make sure to use ./tenks, since just ‘tenks’ will install via PyPI.
export TENKS_CONFIG_PATH=config/src/kayobe-config/tenks.yml
./dev/tenks-deploy.sh ./tenks

# Activate the Kayobe environment, to allow running commands directly.
source dev/environment-setup.sh

# Inspect and provision the overcloud hardware:
kayobe overcloud inventory discover
kayobe overcloud hardware inspect
kayobe overcloud provision

# Deploy the control plane:
# (following https://kayobe.readthedocs.io/en/latest/deployment.html#id3)
kayobe overcloud host configure
kayobe overcloud container image pull
kayobe overcloud service deploy
source config/src/kayobe-config/etc/kolla/public-openrc.sh
kayobe overcloud post configure

# At this point it should be possible to access the Horizon GUI via the seed
# hypervisor's floating IP address, using port 80 (achieved through port
# forwarding).

# Note that when accessing the VNC console of an instance via Horizon, you
# will be sent to the internal IP address of the controller, 192.168.33.2,
# which will fail. Replace this with the floating IP of the seed hypervisor
# VM.

# The following script will register some resources in OpenStack to enable
# booting up a tenant VM.
source config/src/kayobe-config/etc/kolla/public-openrc.sh
./config/src/kayobe-config/init-runonce.sh

# Following the instructions displayed by the above script, boot a VM.
# You'll need to have activated the ~/os-venv virtual environment.
source ~/os-venv/bin/activate
openstack server create --image cirros --flavor m1.tiny --key-name mykey --network demo-net demo1

# Assign a floating IP to the server to make it accessible.
openstack floating ip create public1
fip=$(openstack floating ip list -f value -c 'Floating IP Address' --status DOWN | head -n 1)
openstack server add floating ip demo1 $fip

# Check SSH access to the VM.
ssh cirros@$fip

# Duration
duration=$SECONDS
echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
