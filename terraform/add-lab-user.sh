
cat <<EOF > /etc/ssh/sshd_config
Match user lab
  PasswordAuthentication yes
EOF

useradd -G sudo -p 42ZTHaRqaaYvI lab
service sshd restart

cat <<EOF > /etc/motd

Welcome to the Minikube Lab!

For Kata, startup Minikube as follows:

sudo minikube start \
 --vm-driver kvm2 \
 --cpus 4 \
 --memory 6144 \
 --feature-gates=RuntimeClass=true \
 --network-plugin=cni \
 --enable-default-cni \
 --container-runtime=cri-o \
 --bootstrapper=kubeadm

EOF
