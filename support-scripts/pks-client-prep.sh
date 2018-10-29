#!/bin/sh

apt update
apt upgrade
apt dist-upgrade

apt-get install apache2 jq ruby ruby-dev gcc build-essential g++ openssh-server git -y

gem install cf-uaac

#Enabled ssh to the pksclient:
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.factory
systemctl restart ssh

#Enable RDP to the Ubuntu desktop:
#sudo apt install xrdp
#sudo systemctl enable xrdp

#Enable VNC for remote desktop:
#sudo apt install x11vnc
#x11vnc -storepasswd
#x11vnc -rfbauth /home/vmware/.vnc/passwd &

mkdir -p /DATA/GIT-REPOS/
cd /DATA/GIT-REPOS/
git clone https://github.com/bdereims/pks-prep.git
git clone https://github.com/vmware/nsx-t-datacenter-ci-pipelines.git
git clone https://github.com/sparameswaran/nsx-t-ci-pipeline.git

cd /tmp


