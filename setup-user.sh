
# suppress warning
touch /var/lib/cloud/instance/warnings/.skip

cat <<EOF >> /etc/ssh/sshd_config

Match user root
  PasswordAuthentication yes

EOF

usermod -p 42ZTHaRqaaYvI root
service sshd restart

cat <<EOF > /etc/motd

Welcome to the Kayobe Lab!

Immediately change the default password.

    passwd

Optionally, attach to a screen session in case the connection drops:

    screen -drR

To configure Kayobe, run:

    bash configure-kayobe.sh

To see this directions again:

    cat /etc/motd

EOF
