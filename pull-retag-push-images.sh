#!/bin/bash

set -e

# Reset SECONDS
SECONDS=0

# DISTRO: CentOS or Ubuntu?
DISTRO=ubuntu

if [[ "${DISTRO}" = "ubuntu" ]]
then
    # Install and start docker
    [[ -f /usr/share/keyrings/docker-archive-keyring.gpg ]] || (curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg)
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl enable docker
    sudo systemctl start docker
else
    # Install and start docker
    sudo dnf install -y 'dnf-command(config-manager)'
    cat << "EOF" | sudo tee /etc/yum.repos.d/docker-ce.repo
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/centos/9/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg
module_hotfixes = True
EOF
    sudo dnf install -y docker-ce iptables
    sudo systemctl enable docker
    sudo systemctl start docker
fi

# Start the registry if it does not exist
if [ ! "$(sudo docker ps -q -f name=registry)" ]; then
    sudo docker run -d -p 4000:5000 --restart=always --name registry registry
fi

registry=quay.io
acct=openstack.kolla
if [[ "${DISTRO}" = "ubuntu" ]]
then
    tag=${1:-2023.1-ubuntu-jammy}
else
    tag=${1:-2023.1-rocky-9}
fi
images="bifrost-deploy
kolla-toolbox
haproxy
mariadb-server
mariadb-clustercheck
fluentd
cron
keepalived
neutron-server
neutron-l3-agent
neutron-metadata-agent
neutron-openvswitch-agent
neutron-dhcp-agent
glance-api
nova-compute
keystone-fernet
keystone-ssh
keystone
nova-api
nova-conductor
nova-ssh
nova-novncproxy
nova-scheduler
placement-api
openvswitch-vswitchd
openvswitch-db-server
nova-libvirt
memcached
rabbitmq
heat-api
heat-api-cfn
heat-engine
horizon
opensearch
opensearch-dashboards
barbican-base
barbican-api
barbican-worker
barbican-keystone-listener
magnum-base
magnum-api
magnum-conductor
prometheus-alertmanager
prometheus-v2-server
prometheus-cadvisor
prometheus-haproxy-exporter
prometheus-mtail
prometheus-memcached-exporter
prometheus-blackbox-exporter
prometheus-node-exporter
prometheus-elasticsearch-exporter
prometheus-mysqld-exporter
prometheus-openstack-exporter
prometheus-libvirt-exporter
grafana
cinder-scheduler
cinder-volume
cinder-backup
cinder-api
ovn-controller
ovn-northd
ovn-nb-db-server
ovn-sb-db-server
dnsmasq
ironic-api
ironic-conductor
ironic-inspector
ironic-neutron-agent
ironic-pxe
nova-compute-ironic
manila-api
manila-share
manila-data
manila-scheduler"

for image in $images; do
    echo "Processing $acct/$image:$tag..."
    sudo docker pull $registry/$acct/$image:$tag
    sudo docker tag $registry/$acct/$image:$tag localhost:4000/$acct/$image:$tag
    sudo docker push localhost:4000/$acct/$image:$tag
    sudo docker image remove $registry/$acct/$image:$tag
done

# Duration
duration=$SECONDS
echo "[INFO] $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
