#!/bin/bash

# Reset SECONDS
SECONDS=0

# Cloud User: CentOS or Ubuntu?
CLOUD_USER=centos

# Registry IP
[[ -z "$1" ]] && echo "Usage ./a-seed-from-nothing.sh <registry IP>" && exit 1
registry_ip=$1
echo "[INFO] Given docker registry IP: $registry_ip"

# Disable the firewall.
if [[ "${CLOUD_USER}" = "ubuntu" ]]
then
    dpkg -l ufw && sudo systemctl is-enabled ufw && sudo systemctl stop ufw && sudo systemctl disable ufw
else
    rpm -q firewalld && sudo systemctl is-enabled firewalld && sudo systemctl stop firewalld && sudo systemctl disable firewalld
    sudo sed -i -e 's/^mirrorlist/#mirrorlist/g' \
    -e 's/^#baseurl/baseurl/g' \
    -e 's/mirror\.centos\.org/uk.mirror.nsec.pt/g' /etc/yum.repos.d/CentOS-Stream-*.repo
fi

# Disable SELinux.
sudo setenforce 0

# Useful packages
if [[ "${CLOUD_USER}" = "ubuntu" ]]
then
    sudo apt install -y git tmux lvm2
else
    sudo dnf install -y git tmux lvm2
fi

# Work around connectivity issues seen while configuring this node as seed
# hypervisor with Kayobe
if [[ "${CLOUD_USER}" = "centos" ]]
then
    sudo dnf install -y network-scripts
    sudo rm -f /etc/sysconfig/network-scripts/ifcfg-ens3*
fi
cat <<EOF | sudo tee /etc/sysctl.d/70-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sudo sysctl --load /etc/sysctl.d/70-ipv6.conf

if [[ "${CLOUD_USER}" = "centos" ]]
then
    sudo systemctl is-active NetworkManager && (sudo systemctl disable NetworkManager; sudo systemctl stop NetworkManager)
    sudo systemctl is-active network || (sudo systemctl enable network; sudo pkill dhclient; sudo systemctl start network)
fi

# Exit on error
# NOTE(priteau): Need to be set here as setenforce can return a non-zero exit code
# NOTE(brtknr): pkill dhclient may exit 1 so set -e from here
set -e

# Ensure an ssh key is generated
# NOTE: you might think ~${CLOUD_USER} would work but apparently not
CLOUD_USER_DIR=/home/${CLOUD_USER}
keyfile="$HOME/.ssh/id_rsa"
if [[ ! -f $keyfile ]]
then
    echo "Generating ssh keypair $keyfile"
    ssh-keygen -t rsa -f $keyfile -C 'AUFN Lab user' -P ''
fi
if ! sudo grep -q "$(< $keyfile.pub)" ${CLOUD_USER_DIR}/.ssh/authorized_keys
then
    echo "Authorising keypair for ${CLOUD_USER} user"
    sudo install -d -o ${CLOUD_USER} -g ${CLOUD_USER} -m 0700 ${CLOUD_USER_DIR}/.ssh
    sudo -u ${CLOUD_USER} ls -l ${CLOUD_USER_DIR}/.ssh/authorized_keys
    cat $keyfile.pub | sudo -u ${CLOUD_USER} tee -a ${CLOUD_USER_DIR}/.ssh/authorized_keys
    sudo chmod 0600 ${CLOUD_USER_DIR}/.ssh/authorized_keys
    sudo chown ${CLOUD_USER}.${CLOUD_USER} ${CLOUD_USER_DIR}/.ssh/authorized_keys
if ! sudo grep -q "$(< $keyfile.pub)" ~centos/.ssh/authorized_keys
then
    echo "Authorizing keypair for centos user"
    sudo install -d -o centos -g centos -m 0700 ~centos/.ssh
    cat $keyfile.pub | sudo -u centos tee -a ~centos/.ssh/authorized_keys
    sudo chmod 0600 ~centos/.ssh/authorized_keys
    sudo chown centos.centos ~centos/.ssh/authorized_keys
fi

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
[[ -d kayobe-config ]] || git clone https://github.com/stackhpc/a-universe-from-nothing.git -b wallaby-ovn-monitoring kayobe-config

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
