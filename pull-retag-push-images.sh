#!/bin/bash

set -e

# Reset SECONDS
SECONDS=0

if type apt; then
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

if type apt; then
    tag=${1:-2025.1-ubuntu-jammy}
else
    tag=${1:-2025.1-rocky-10}
fi

images="barbican-api
barbican-keystone-listener
barbican-worker
bifrost-deploy
blazar-api
blazar-manager
cinder-api
cinder-backup
cinder-scheduler
cinder-volume
cloudkitty-api
cloudkitty-processor
cron
designate-api
designate-backend-bind9
designate-central
designate-mdns
designate-producer
designate-sink
designate-worker
dnsmasq
etcd
fluentd
glance-api
grafana
haproxy
haproxy-ssh
heat-api
heat-api-cfn
heat-engine
horizon
influxdb
ironic-api
ironic-conductor
ironic-inspector
ironic-neutron-agent
ironic-prometheus-exporter
ironic-pxe
keepalived
keystone
keystone-fernet
keystone-ssh
kolla-toolbox
letsencrypt-lego
letsencrypt-webserver
magnum-api
magnum-conductor
manila-api
manila-data
manila-scheduler
manila-share
mariadb-clustercheck
mariadb-server
memcached
neutron-bgp-dragent
neutron-dhcp-agent
neutron-l3-agent
neutron-metadata-agent
neutron-mlnx-agent
neutron-openvswitch-agent
neutron-server
neutron-sriov-agent
nova-api
nova-compute
nova-compute-ironic
nova-conductor
nova-libvirt
nova-novncproxy
nova-scheduler
nova-serialproxy
nova-ssh
octavia-api
octavia-driver-agent
octavia-health-manager
octavia-housekeeping
octavia-worker
opensearch
opensearch-dashboards
openvswitch-db-server
openvswitch-vswitchd
ovn-controller
ovn-nb-db-server
ovn-northd
ovn-sb-db-server
placement-api
prometheus-alertmanager
prometheus-blackbox-exporter
prometheus-cadvisor
prometheus-elasticsearch-exporter
prometheus-libvirt-exporter
prometheus-memcached-exporter
prometheus-msteams
prometheus-mtail
prometheus-mysqld-exporter
prometheus-node-exporter
prometheus-openstack-exporter
prometheus-v2-server
rabbitmq
rabbitmq-4-1"

if type apt; then
images="${images}
redis
redis-sentinel"
else
images="${images}
valkey-server
valkey-sentinel"
fi

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
