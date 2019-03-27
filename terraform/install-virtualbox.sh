
# suppress apt-key warning message
export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -

sudo add-apt-repository "deb http://download.virtualbox.org/virtualbox/debian bionic contrib"

apt-get update

sudo apt-get -y install gcc make linux-headers-$(uname -r) dkms

apt-get install virtualbox-6.0 -y
