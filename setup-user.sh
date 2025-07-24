#!/bin/bash

sudo groupadd wheel
sudo useradd -m -G wheel -s /bin/bash lab

cat <<EOF | sudo tee -a /etc/ssh/sshd_config

Match user lab
  PasswordAuthentication yes

EOF

sudo systemctl restart sshd

cat <<EOF | sudo tee -a /etc/sudoers.d/91-wheel-group

%wheel  ALL=(ALL)       NOPASSWD: ALL

EOF

