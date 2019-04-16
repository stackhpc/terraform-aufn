yum install -y screen git
screen -L -d -m bash install-kayobe.sh
sleep 1 # https://github.com/hashicorp/terraform/issues/6229
