# pull over repos for the Kata workshop

apt-get install git -y

pushd ~lab
sudo -u lab git clone https://github.com/kata-containers/tests.git
sudo -u lab git clone https://github.com/kata-containers/packaging
sudo -u lab git clone https://github.com/clearlinux/cloud-native-setup
popd
