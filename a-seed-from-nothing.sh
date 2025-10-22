#!/bin/bash

# Reset SECONDS
SECONDS=0

ENABLE_OVN=true

# Registry IP
[[ -z "$1" ]] && echo "Usage ./a-seed-from-nothing.sh <registry IP>" && exit 1
registry_ip=$1
echo "[INFO] Given docker registry IP: $registry_ip"

# Disable the firewall.
if type apt; then
    grep -q $HOSTNAME /etc/hosts || (echo "$(ip r | grep -o '^default via.*src [0-9.]*' | awk '{print $NF}') $HOSTNAME" | sudo tee -a /etc/hosts)
    dpkg -l ufw && sudo systemctl is-enabled ufw && sudo systemctl stop ufw && sudo systemctl disable ufw
else
    rpm -q firewalld && sudo systemctl is-enabled firewalld && sudo systemctl stop firewalld && sudo systemctl disable firewalld

    # Disable SELinux.
    sudo setenforce 0
fi

# Useful packages
if type apt; then
    # Avoid the interactive dialog prompting for service restart: set policy to leave services unchanged
    echo "\$nrconf{restart} = 'l';" | sudo tee /etc/needrestart/conf.d/90-aufn.conf
    sudo apt update
    sudo apt install -y git tmux lvm2 iptables
else
    sudo dnf install -y git tmux lvm2 patch openssh
fi

# Work around connectivity issues seen while configuring this node as seed
# hypervisor with Kayobe
cat <<EOF | sudo tee /etc/sysctl.d/70-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sudo sysctl --load /etc/sysctl.d/70-ipv6.conf

# CentOS Stream 8 requires network-scripts.  Rocky Linux 9 and onwards use NetworkManager.
if type dnf; then
    case $(grep -o "[89]\.[0-9]" /etc/redhat-release) in
      "8.*")
        sudo dnf install -y network-scripts
        sudo rm -f /etc/sysconfig/network-scripts/ifcfg-ens3*
        sudo systemctl is-active NetworkManager && (sudo systemctl disable NetworkManager; sudo systemctl stop NetworkManager)
        sudo systemctl is-active network || (sudo systemctl enable network; sudo pkill dhclient; sudo systemctl start network)
        ;;
      "9.*")
        # No network-scripts for RL9
        sudo systemctl is-active NetworkManager || (sudo systemctl enable NetworkManager; sudo systemctl start NetworkManager)
        ;;
      "*")
        echo "Could not recognise OS release $(< /etc/redhat-release)"
        exit -1
        ;;
    esac
elif type apt; then
    # Prepare for disabling of Netplan and enabling of systemd-networkd.
    # Netplan has an interaction with systemd and cloud-init to populate
    # systemd-networkd files, but ephemerally.  If /etc/systemd/network is
    # empty and netplan config files are present in /run, copy them over.
    persistent_netcfg=$(ls /etc/systemd/network)
    ephemeral_netcfg=$(ls /run/systemd/network)
    if [[ -z "$persistent_netcfg" && ! -z "$ephemeral_netcfg" ]]
    then
        echo "Creating persistent versions of Netplan ephemeral config"
        sudo cp /run/systemd/network/* /etc/systemd/network
    fi
fi

# Exit on error
# NOTE(priteau): Need to be set here as setenforce can return a non-zero exit code
# NOTE(brtknr): pkill dhclient may exit 1 so set -e from here
set -e

# Ensure an ssh key is generated
CLOUD_USER=$(ls /home | grep -v lab | grep -v stack | head -1)
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
fi

# Clone Beokay.
cd $HOME
git clone https://github.com/stackhpc/beokay.git -b master

# Use Beokay to bootstrap your control host.
[[ -d deployment ]] || beokay/beokay.py create --base-path ~/deployment --kayobe-repo https://github.com/stackhpc/kayobe.git --kayobe-branch stackhpc/2024.1 --kayobe-config-repo https://github.com/stackhpc/a-universe-from-nothing.git --kayobe-config-branch stable/2024.1

# Bump the provisioning time - it can be lengthy on virtualised storage
sed -i.bak 's%^[# ]*wait_active_timeout:.*%    wait_active_timeout: 5000%' ~/deployment/src/kayobe/ansible/overcloud-provision.yml

# Clone the Tenks repository.
cd ~/deployment/src/
[[ -d tenks ]] || git clone https://opendev.org/openstack/tenks.git
cd

# Set default registry name to the one we just created
sed -i.bak 's/^docker_registry:.*/docker_registry: '$registry_ip':4000/' ~/deployment/src/kayobe-config/etc/kayobe/docker.yml

# Configure host networking (bridge, routes & firewall)
~/deployment/src/kayobe-config/configure-local-networking.sh

# Enable OVN flags
if $ENABLE_OVN
then
    cat <<EOF | sudo tee -a ~/deployment/src/kayobe-config/etc/kayobe/bifrost.yml
kolla_bifrost_extra_kernel_options:
  - "console=ttyS0"
EOF
    cat <<EOF | sudo tee -a ~/deployment/src/kayobe-config/etc/kayobe/kolla.yml
kolla_enable_ovn: yes
EOF
    cat <<EOF | sudo tee -a ~/deployment/src/kayobe-config/etc/kayobe/neutron.yml
kolla_neutron_ml2_type_drivers:
  - geneve
  - vlan
  - flat
kolla_neutron_ml2_tenant_network_types:
  - geneve
  - vlan
  - flat
EOF
fi

# Set Environment variables for Kayobe dev scripts
export KAYOBE_CONFIG_SOURCE_PATH=~/deployment/src/kayobe-config
export KAYOBE_VENV_PATH=~/deployment/venvs/kayobe

# Deploy hypervisor services.
~/deployment/src/kayobe/dev/seed-hypervisor-deploy.sh

# Deploy a seed VM.
# NOTE: This should work the first time because the packet configuration uses a
# custom docker registry.  However, there are sometimes issues with Docker starting up on the seed (FIXME)
if ! ~/deployment/src/kayobe/dev/seed-deploy.sh; then
    # Deploy a seed VM. Should work this time.
    ~/deployment/src/kayobe/dev/seed-deploy.sh
fi

# Run TENKS
export TENKS_CONFIG_PATH=~/deployment/src/kayobe-config/tenks.yml
~/deployment/src/kayobe/dev/tenks-deploy-overcloud.sh ~/deployment/src/tenks

if [[ -f ~/deployment/src/kayobe/dev/tenks-network-reboot-patch.sh ]]; then
    echo "Setting up Tenks network persistence..."

    # Make sure unit service and script are executable 
    chmod +x ~/deployment/src/kayobe-config/tenks-network-on-boot.service
    chmod +x ~/deployment/src/kayobe-config/tenks-network-setup

    # Move Service and Script to correct directory
    sudo mv ~/deployment/src/kayobe-config/tenks-network-on-boot.service /etc/systemd/system/
    sudo mv ~/deployment/src/kayobe-config/tenks-network-setup /bin/

    # Enable Service
    sudo systemctl enable tenks-network-on-boot.service
else
    echo "This version of Kayobe doesn't support Tenks network persistance."
fi

# Duration
duration=$SECONDS
echo "[INFO] $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
