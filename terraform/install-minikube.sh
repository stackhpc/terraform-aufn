curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
cp minikube /usr/local/bin
rm minikube

minikube start  --vm-driver kvm2  --cpus 4  --memory 6144  --feature-gates=RuntimeClass=true  \
	--network-plugin=cni  --enable-default-cni  --container-runtime=cri-o  --bootstrapper=kubeadm
minikube stop


