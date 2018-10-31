#!/bin/bash
# This script contains commands from pks-client-setup.sh script from bdereims@vmware.com
#Only tested on Ubuntu 16.04/18.04 LTS
# run this script as sudo

f_info(){
    today=`date +%Y-%m-%d.%H:%M:%S`

    echo "***************************************************************"
    echo "[ $today ]  INFO  $*"
    echo "***************************************************************"
}

f_startup_question() {
    clear
    echo "***************************************************************"
    echo "RUN THIS SCRIPT AS SUDO!"
    echo "***************************************************************"
    echo "Welcome to NSX-T and PKS Pipeline configuration!"
    echo "Note: In order to run the script you will need VMware user, VMware password and DNS details"
    echo "***************************************************************"
    while true; do
        read -p "Do you wish to start? (y/n)" yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    echo "***************************************************************"

}

f_choice_question() {
    clear
    echo "***************************************************************"
    echo "  What would you like to do today?"
    echo "***************************************************************"
    echo "  Available options:"
    echo "  a - prepare all pipelines for PKS and NSX-T "
    echo "  n - prepare pipeline for NSX-T only"
    echo "  p - prepare pipeline for PKS only"
    echo "  c - clean-up pipelines"
    echo "  e - exit"
    echo "***************************************************************"
    while true; do
        read -p "   Do you wish to start? (a|n|p|c|e)" anpce
        case $anpce in
            [Aa]* ) clear;
                    break;;
            [Nn]* ) f_install_packages;
                    f_download_vmmare_repo;
                    f_start_nsx_docker;
                    break;;
            [Pp]* ) clear;
                    break;;
            [Cc]* ) clear;
                    break;;
            [Ee]* ) exit;;
            * ) echo "Please answer one of the available options";;
        esac
    done
    echo "***************************************************************"

}

f_input_vars() {

    read -p "$1 [ i.e. $2 ]: " $1
    echo $1 " = " ${!1}
    echo "---------------------------"
}

f_input_vars_sec() {

    read -sp "$1: " $1
    echo
    echo $1 = ${!1}
    echo "Set: $1 = **************"
    echo "---------------------------"
}

f_install_packages() {

    f_info "Updating OS and installing packages"
    add-apt-repository universe
    apt-get update ; sudo apt-get upgrade
    apt-get install -y docker openssh-server git apt-transport-https ca-certificates curl software-properties-common build-essential
    apt-get zlibc zlib1g-dev ruby ruby-dev openssl libxslt1-dev libxml2-dev libssl-dev libreadline-dev libyaml-dev libsqlite3-dev
    apt-get sqlite3 sshpass jq dnsmasq iperf3 sshpass ipcalc curl npm

    f_info "Installing vmw-cli tool"
    # vwm-cli - requires nodejs >=8
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
    apt-get install -y nodejs
    npm install vmw-cli --global
}

f_download_vmmare_repo(){
    wget https://github.com/vmware/nsx-t-datacenter-ci-pipelines/raw/master/docker_image/nsx-t-install-09122018.tar -O nsx-t-install.tar
    docker load -i nsx-t-install.tar
    mkdir -p /home/concourse

    f_info "Downloading supporting github repos"
    if [[ ! -e /DATA/GIT-REPOS ]]; then
        mkdir -p /DATA/GIT-REPOS/
    fi

    git clone https://github.com/agilderdale/pks-env.git
    git clone https://github.com/vmware/nsx-t-datacenter-ci-pipelines.git
    git clone https://github.com/sparameswaran/nsx-t-ci-pipeline.git

    cp /DATA/GIT-REPOS/pks-env/config_files/*.yml /home/concourse/
}

f_start_nsx_docker(){
    CONCOURSE_IP=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
    f_input_vars EXTERNAL_DNS DNS_IP
    f_input_vars VMWARE_USER my_user
    f_input_vars_sec VMWARE_PASSWORD my_passwd
    f_input_vars NSXT_VERSION 2.3

    docker run --name nsx-t-install -d \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /home/concourse:/home/concourse \
      -e CONCOURSE_URL="http://${CONCOURSE_IP}:8080" \
      -e EXTERNAL_DNS="$EXTERNAL_DNS" \
      -e IMAGE_WEBSERVER_PORT=40001 \
      -e VMWARE_USER='$VMWARE_USER' \
      -e VMWARE_PASSWORD='$VMWARE_PASSWORD' \
      -e NSXT_VERSION='$NSXT_VERSION'
      nsx-t-install:0.1
}



f_prep_vars(){
    if [[ ! -e $BITSDIR ]];
    then
        mkdir -p $BITSDIR;
    fi
    f_install_packages
    f_input_vars BITSDIR /DATA/bits
}

#####################################
# MAIN
#####################################
BINDIR=/usr/local/bin

f_startup_question
f_choice_question


f_info "PKS Client setup COMPLETED - please check logs for details"

