#!/bin/bash

sudo groupadd wheel
sudo useradd -m -G wheel -s /bin/bash lab

cat <<EOF | sudo tee /etc/ssh/sshd_config.d/60-lab-user.conf

Match user lab
  PasswordAuthentication yes

EOF

sudo systemctl restart sshd

cat <<EOF | sudo tee /etc/sudoers.d/91-wheel-group

%wheel  ALL=(ALL)       NOPASSWD: ALL

EOF

cat <<EOF | sudo tee /etc/motd

Welcome to the Kayobe Lab!

Optionally, attach to a tmux session in case the connection drops:

    tmux

To view the script that was used to deploy the seed in this instance:

    < a-seed-from-nothing.sh

To view the instructions for deploying the control plane:

    < a-universe-from-seed.sh

To see this directions again:

    < /etc/motd

EOF
