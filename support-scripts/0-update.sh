#!/bin/bash
#bdereims@vmware.com
#Only tested on Ubuntu 16.04/18.04 LTS

BINDIR=/usr/local/bin
BOSHRELEASE=5.3.1
HELMRELEASE=2.11.0
OMRELEASE=0.42.0
PIVNETRELEASE=0.0.55
BITSDIR=/DATA/bits
APIREFRESHTOKEN=''
PKSRELEASE=1.2.0
#checking and creating BITSDIR if needed
if [[ ! -e $BITSDIR ]]; then
    mkdir $BITSDIR
fi

add-apt-repository universe
apt-get update ; sudo apt-get upgrade
apt-get install -y build-essential zlibc zlib1g-dev ruby ruby-dev openssl libxslt1-dev libxml2-dev libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 sshpass jq dnsmasq iperf3 sshpass ipcalc curl
apt-get npm

# vwm-cli - requires nodejs >=8
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
apt-get install -y nodejs
npm install vmw-cli --global

# uuac
gem install cf-uaac

# kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl
cp kubectl $BINDIR/kubectl
rm kubectl

# bosh
curl -LO https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${BOSHRELEASE}-linux-amd64
cp bosh-cli-${BOSHRELEASE}-linux-amd64 ${BINDIR}/bosh
chmod ugo+x ${BINDIR}/bosh 
rm bosh-cli-${BOSHRELEASE}-linux-amd64

# om
curl -LO https://github.com/pivotal-cf/om/releases/download/${OMRELEASE}/om-linux
chown root om-linux
chmod ugo+x om-linux
mv om-linux ${BINDIR}/om

# helm
curl -LO https://kubernetes-helm.storage.googleapis.com/helm-v${HELMRELEASE}-linux-amd64.tar.gz
tar xvzf helm-v${HELMRELEASE}-linux-amd64.tar.gz linux-amd64/helm
chmod +x linux-amd64/helm
cp linux-amd64/helm ${BINDIR}/helm
rm -fr linux-amd64
rm helm-v${HELMRELEASE}-linux-amd64.tar.gz

# pivnet cli
curl -LO https://github.com/pivotal-cf/pivnet-cli/releases/download/v${PIVNETRELEASE}/pivnet-linux-amd64-${PIVNETRELEASE}

chown root pivnet-linux-amd64-${PIVNETRELEASE}
chmod ugo+x pivnet-linux-amd64-${PIVNETRELEASE}
mv pivnet-linux-amd64-${PIVNETRELEASE} ${BINDIR}/pivnet

# Download PKS CLI from Pivotal Network - require user token
if [ -z $APIREFRESHTOKEN ]
then
    read -sp 'PIVOTAL_TOKEN: ' APIREFRESHTOKEN
    echo
 #   echo "Update APIREFRESHTOKEN value in set_env before running it"
 #   exit 1
fi


# pks cli
pivnet login --api-token=$APIREFRESHTOKEN
PKSFileID=`pivnet pfs -p pivotal-container-service -r $PKSRELEASE | grep 'PKS CLI - Linux' | awk '{ print $2}'`
pivnet download-product-files -p pivotal-container-service -r $PKSRELEASE -i $PKSFileID

mv pks-linux-amd64* pks 
chown root:root pks
chmod +x pks
cp pks ${BINDIR}/pks


