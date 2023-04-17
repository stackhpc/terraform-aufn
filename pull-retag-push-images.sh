#!/bin/bash

set -e

# Reset SECONDS
SECONDS=0

# DISTRO: CentOS or Ubuntu?
DISTRO=centos

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
baseurl=https://download.docker.com/linux/centos/8/$basearch/stable
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

tag=${1:-yoga}
images="kolla/${DISTRO}-source-bifrost-deploy
kolla/${DISTRO}-source-kolla-toolbox
kolla/${DISTRO}-source-haproxy
kolla/${DISTRO}-source-mariadb-server
kolla/${DISTRO}-source-mariadb-clustercheck
kolla/${DISTRO}-source-fluentd
kolla/${DISTRO}-source-cron
kolla/${DISTRO}-source-keepalived
kolla/${DISTRO}-source-neutron-server
kolla/${DISTRO}-source-neutron-l3-agent
kolla/${DISTRO}-source-neutron-metadata-agent
kolla/${DISTRO}-source-neutron-openvswitch-agent
kolla/${DISTRO}-source-neutron-dhcp-agent
kolla/${DISTRO}-source-glance-api
kolla/${DISTRO}-source-nova-compute
kolla/${DISTRO}-source-keystone-fernet
kolla/${DISTRO}-source-keystone-ssh
kolla/${DISTRO}-source-keystone
kolla/${DISTRO}-source-nova-api
kolla/${DISTRO}-source-nova-conductor
kolla/${DISTRO}-source-nova-ssh
kolla/${DISTRO}-source-nova-novncproxy
kolla/${DISTRO}-source-nova-scheduler
kolla/${DISTRO}-source-placement-api
kolla/${DISTRO}-source-openvswitch-vswitchd
kolla/${DISTRO}-source-openvswitch-db-server
kolla/${DISTRO}-source-nova-libvirt
kolla/${DISTRO}-source-memcached
kolla/${DISTRO}-source-rabbitmq
kolla/${DISTRO}-source-heat-api
kolla/${DISTRO}-source-heat-api-cfn
kolla/${DISTRO}-source-heat-engine
kolla/${DISTRO}-source-horizon
kolla/${DISTRO}-source-kibana
kolla/${DISTRO}-source-elasticsearch
kolla/${DISTRO}-source-elasticsearch-curator
kolla/${DISTRO}-source-barbican-base
kolla/${DISTRO}-source-barbican-api
kolla/${DISTRO}-source-barbican-worker
kolla/${DISTRO}-source-barbican-keystone-listener
kolla/${DISTRO}-source-magnum-base
kolla/${DISTRO}-source-magnum-api
kolla/${DISTRO}-source-magnum-conductor
kolla/${DISTRO}-source-prometheus-alertmanager
kolla/${DISTRO}-source-prometheus-v2-server
kolla/${DISTRO}-source-prometheus-cadvisor
kolla/${DISTRO}-source-prometheus-haproxy-exporter
kolla/${DISTRO}-source-prometheus-mtail
kolla/${DISTRO}-source-prometheus-memcached-exporter
kolla/${DISTRO}-source-prometheus-blackbox-exporter
kolla/${DISTRO}-source-prometheus-node-exporter
kolla/${DISTRO}-source-prometheus-elasticsearch-exporter
kolla/${DISTRO}-source-prometheus-mysqld-exporter
kolla/${DISTRO}-source-prometheus-openstack-exporter
kolla/${DISTRO}-source-prometheus-libvirt-exporter
kolla/${DISTRO}-source-grafana
kolla/${DISTRO}-source-cinder-scheduler
kolla/${DISTRO}-source-cinder-volume
kolla/${DISTRO}-source-cinder-backup
kolla/${DISTRO}-source-cinder-api
kolla/${DISTRO}-source-ovn-controller
kolla/${DISTRO}-source-ovn-northd
kolla/${DISTRO}-source-ovn-nb-db-server
kolla/${DISTRO}-source-ovn-sb-db-server"

for image in $images; do
    sudo docker pull $image:$tag
    sudo docker tag docker.io/$image:$tag localhost:4000/openstack.$image:$tag
    sudo docker push localhost:4000/openstack.$image:$tag
    sudo docker image remove docker.io/$image:$tag
done

# Duration
duration=$SECONDS
echo "[INFO] $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
