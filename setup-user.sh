#!/bin/bash

useradd -m -G wheel -p 42ZTHaRqaaYvI -s /bin/bash lab

cat <<EOF >> /etc/ssh/sshd_config

Match user lab
  PasswordAuthentication yes

EOF

service sshd restart

cat <<EOF >> /etc/sudoers

%wheel  ALL=(ALL)       NOPASSWD: ALL

EOF

cat <<EOF > /etc/motd

Welcome to the Kayobe Lab!

Immediately change the default password.

    passwd

Optionally, attach to a screen session in case the connection drops:

    screen -drR

To deploy the control plane using the predeployed seed, run:

    bash a-universe-from-seed.sh

To see this directions again:

    cat /etc/motd

EOF
