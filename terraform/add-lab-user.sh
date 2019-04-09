
# suppress warning
touch /var/lib/cloud/instance/warnings/.skip

cat <<EOF >> /etc/ssh/sshd_config
Match user lab
  PasswordAuthentication yes
EOF

useradd -m -G sudo -p 42ZTHaRqaaYvI -s /bin/bash lab
service sshd restart

cat <<EOF > /etc/motd

Welcome to the Minikube Lab!

To setup the lab, run the following scripts:

Startup Minikube as follows for use with running Kata:

minikube start \\
 --vm-driver kvm2 \\
 --cpus 4 \\
 --memory 6144 \\
 --feature-gates=RuntimeClass=true \\
 --network-plugin=cni \\
 --enable-default-cni \\
 --container-runtime=cri-o \\
 --bootstrapper=kubeadm

To see this directions again:
cat /etc/motd

EOF
