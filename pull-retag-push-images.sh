#!/bin/bash

set -e

# Reset SECONDS
SECONDS=0

# Mount the second volume to provide additional capacity
if ! grep -q /dev/vdb /proc/mounts
then
    sudo mkfs -t ext4 /dev/vdb
    sudo mkdir -p /var/lib/docker
    sudo mount -t ext4 /dev/vdb /var/lib/docker
    echo "/dev/vdb /var/lib/docker ext4 defaults 0 0" | sudo tee -a /etc/fstab
fi

# Install and start docker
[[ -f /usr/share/keyrings/docker-archive-keyring.gpg ]] || (curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker
sudo systemctl start docker

# Start the registry if it does not exist
if [ ! "$(sudo docker ps -q -f name=registry)" ]; then
    sudo docker run -d -p 4000:5000 --restart=always --name registry registry
fi

tag=${1:-wallaby}
images="kolla/ubuntu-source-kolla-toolbox
kolla/ubuntu-source-haproxy
kolla/ubuntu-source-mariadb-server
kolla/ubuntu-source-mariadb-clustercheck
kolla/ubuntu-source-fluentd
kolla/ubuntu-source-cron
kolla/ubuntu-source-keepalived
kolla/ubuntu-source-neutron-server
kolla/ubuntu-source-neutron-l3-agent
kolla/ubuntu-source-neutron-metadata-agent
kolla/ubuntu-source-neutron-openvswitch-agent
kolla/ubuntu-source-neutron-dhcp-agent
kolla/ubuntu-source-glance-api
kolla/ubuntu-source-nova-compute
kolla/ubuntu-source-keystone-fernet
kolla/ubuntu-source-keystone-ssh
kolla/ubuntu-source-keystone
kolla/ubuntu-source-nova-api
kolla/ubuntu-source-nova-conductor
kolla/ubuntu-source-nova-ssh
kolla/ubuntu-source-nova-novncproxy
kolla/ubuntu-source-nova-scheduler
kolla/ubuntu-source-placement-api
kolla/ubuntu-source-openvswitch-vswitchd
kolla/ubuntu-source-openvswitch-db-server
kolla/ubuntu-source-nova-libvirt
kolla/ubuntu-source-memcached
kolla/ubuntu-source-rabbitmq
kolla/ubuntu-source-chrony
kolla/ubuntu-source-heat-api
kolla/ubuntu-source-heat-api-cfn
kolla/ubuntu-source-heat-engine
kolla/ubuntu-source-horizon
kolla/ubuntu-source-kibana
kolla/ubuntu-source-elasticsearch
kolla/ubuntu-source-elasticsearch-curator
kolla/ubuntu-source-barbican-base
kolla/ubuntu-source-barbican-api
kolla/ubuntu-source-barbican-worker
kolla/ubuntu-source-barbican-keystone-listener
kolla/ubuntu-source-magnum-base
kolla/ubuntu-source-magnum-api
kolla/ubuntu-source-magnum-conductor
kolla/ubuntu-source-prometheus-alertmanager
kolla/ubuntu-source-prometheus-v2-server
kolla/ubuntu-source-prometheus-server
kolla/ubuntu-source-prometheus-cadvisor
kolla/ubuntu-source-prometheus-haproxy-exporter
kolla/ubuntu-source-prometheus-mtail
kolla/ubuntu-source-prometheus-memcached-exporter
kolla/ubuntu-source-prometheus-blackbox-exporter
kolla/ubuntu-source-prometheus-node-exporter
kolla/ubuntu-source-prometheus-elasticsearch-exporter
kolla/ubuntu-source-prometheus-mysqld-exporter
kolla/ubuntu-source-prometheus-openstack-exporter
kolla/ubuntu-source-grafana
kolla/ubuntu-source-cinder-scheduler
kolla/ubuntu-source-cinder-volume
kolla/ubuntu-source-cinder-backup
kolla/ubuntu-source-cinder-api
kolla/ubuntu-source-bifrost-deploy"

for image in $images; do
    sudo docker pull $image:$tag
    sudo docker tag docker.io/$image:$tag localhost:4000/$image:$tag
    sudo docker push localhost:4000/$image:$tag
    sudo docker image remove docker.io/$image:$tag
done

# Duration
duration=$SECONDS
echo "[INFO] $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
