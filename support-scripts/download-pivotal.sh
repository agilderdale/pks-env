#!/bin/bash

PIVOTAL_TOKEN=

PKS_PKG_API="https://network.pivotal.io/api/v2/products/pivotal-container-service/releases/191865/product_files/222375/download"
PKS_PKG_NAME="pivotal-container-service-1.2.0-build.47.pivotal"

HARBOR_PKG_API="https://network.pivotal.io/api/v2/products/harbor-container-registry/releases/190421/product_files/220843/download"
HARBOR_PKG_NAME="harbor-container-registry-1.6.0-build.35.pivotal"

STEMCELL_PKG_API="https://network.pivotal.io/api/v2/products/stemcells-ubuntu-xenial/releases/214330/product_files/247325/download"
STEMCELL_PKG_NAME="bosh-stemcell-97.28-vsphere-esxi-ubuntu-xenial-go_agent.tgz"

#for PREFIX in PKS HARBOR STEMCELL
for PREFIX in STEMCELL
do
 PKG_API="${PREFIX}_PKG_API"
 PKG_NAME="${PREFIX}_PKG_NAME"

#wget --post-data="" --header="Authorization: Token hss2WKxn86fEL8W4VaJk" https://network.pivotal.io/api/v2/products/pivotal-container-service/releases/191865/product_files/222375/download -O "pivotal-container-service-1.2.0-build.47.pivotal"

  echo "Downloading ${!PKG_NAME}..."
  echo ${!PKG_NAME}
  wget --post-data="" --header="Authorization: Token $PIVOTAL_TOKEN" ${!PKG_API} -O " ${!PKG_NAME}"
 
  if [ $? != 0 ]; then echo "Cannot connect to the download page or file is not correct"; break; fi
done
