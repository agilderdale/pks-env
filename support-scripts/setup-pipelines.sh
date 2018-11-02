#!/bin/bash
# Created and maintained by Alicja Gilderdale - https://github.com/agilderdale/pks-env.git
# This script is for setting up concourse pipeline to run NSX-T and PKS install and config.
#Tested on Ubuntu 18.04 LTS
# run this script as sudo
# bash -c "$(wget -O - https://raw.githubusercontent.com/agilderdale/pks-env/master/support-scripts/setup-pipelines.sh)"

BINDIR=/usr/local/bin
BITSDIR=/DATA/bits
CONCOURSE_IP=''
EXTERNAL_DNS=''
VMWARE_USER=''
VMWARE_PASSWORD=''
NSXT_VERSION=2.3
CONFIG_DIR='/DATA/GIT-REPOS/pks-env/config_files/home-lab'

f_info(){
    today=`date +%H:%M:%S`

    echo "*******************************************************************************************"
    echo "[ $today ] INF  ${FUNCNAME[ 1 ]}: $*"
    echo "*******************************************************************************************"
}

f_error(){
    today=`date +%Y-%m-%d.%H:%M:%S`

    echo "*******************************************************************************************"
    echo "[ $today ] ERR  ${FUNCNAME[ 1 ]}: $*"
    echo "*******************************************************************************************"
}

f_verify(){
    rc=`echo $?`
    if [ $rc != 0 ] ; then
        f_error "Last command - FAILED !!!"
        exit 1
    fi
}

f_startup_question() {
    clear
    echo "  ================================================"
    echo "  ================================================"
    echo ""
    echo "  =========== RUN THIS SCRIPT AS SUDO! ==========="
    echo ""
    echo "  ================================================"
    echo ""
    echo "  Welcome to SETUP CONCOURSE PIPELINE script!"
    echo ""
    echo "  ================================================"
    echo ""
    while true; do
        read -p "    Do you wish to start? (y/n): " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo "   =============="
                    echo "      GOODBYE!"
                    echo "   =============="
                    exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    echo "    ========================================"

}

f_choice_question() {
    clear
    while true; do
        echo "*******************************************************************************************"
        echo "  What would you like to do today?"
        echo "*******************************************************************************************"
        echo "  Available options:"
        echo "  p - setup PKS and NSX-T pipelines"
        echo "  t - test variables"
        echo "  e - exit"
        echo "*******************************************************************************************"
        read -p "   Select one of the options? (p|e|t): " pet

        case $pet in
            [Pp]* ) clear;
                    f_init;
                    f_install_packages;
                    f_download_vmmare_repo;
                    f_start_docker;
                    ;;
            [Tt]* ) clear;
                    f_init;
                    f_input_vars CONCOURSE_IP;
                    f_input_vars EXTERNAL_DNS;
                    f_input_vars VMWARE_USER;
                    f_input_vars_sec VMWARE_PASSWORD;
                    f_input_vars NSXT_VERSION;
                    ;;
            [Ee]* ) exit;;
            * ) echo "Please answer one of the available options";;
        esac
    done
    echo "*******************************************************************************************"

}

f_input_vars() {
    var=$1
    temp=${!1}
    read -p "Set $1 [ default: ${!1} ]: " $1

    if [[ -z ${!1} ]] ; then
        if [[ -z $temp ]] ; then
            f_error "The $1 variable has no default value!!! User input is required - EXITING! "
            exit 1
        else
            declare $var=$temp
            echo "export $var=${!var}" >> /tmp/pks_variables
            echo "Set to default: $var="${!var}
        fi
    else
        echo "Variable set to: $1 = " ${!1}
        echo "export $1=${!1}" >> /tmp/pks_variables
    fi
    echo "---------------------------"
}

f_input_vars_sec() {

    read -sp "$1: " $1
    echo
    if [[ -z ${!1} ]]
    then
        f_error "The $1 variable has no default value!!! User input is required - EXITING! "
        exit 1
    fi
    echo "Set: $1 = **************"
    echo "---------------------------"
}

f_install_packages() {

    f_info "Updating OS and installing packages"
    add-apt-repository universe
    apt-get update ; sudo apt-get upgrade
    apt-get install -y openssh-server git apt-transport-https ca-certificates curl software-properties-common build-essential
    apt-get install -y net-tools zlibc zlib1g-dev ruby ruby-dev openssl libxslt1-dev libxml2-dev libssl-dev libreadline-dev libyaml-dev libsqlite3-dev
    apt-get install -y sqlite3 sshpass jq dnsmasq iperf3 sshpass ipcalc curl npm
    apt install docker.io

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

    cp ${CONFIG_DIR}/*.yml /home/concourse/
}

f_start_docker(){
#    CONCOURSE_IP=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
    f_input_vars CONCOURSE_IP
    f_input_vars EXTERNAL_DNS
    f_input_vars VMWARE_USER
    f_input_vars_sec VMWARE_PASSWORD
    f_input_vars NSXT_VERSION
    f_input_vars CONFIG_DIR

    source /tmp/pks_variables

    docker run --name nsx-t-install -d \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /home/concourse:/home/concourse \
      -e CONCOURSE_URL="http://${CONCOURSE_IP}:8080" \
      -e EXTERNAL_DNS="$EXTERNAL_DNS" \
      -e IMAGE_WEBSERVER_PORT=40001 \
      -e VMWARE_USER='$VMWARE_USER' \
      -e VMWARE_PASSWORD='$VMWARE_PASSWORD' \
      -e NSXT_VERSION='$NSXT_VERSION' \
      nsx-t-install
}

f_init(){
    f_input_vars BITSDIR

    source /tmp/pks_variables

    if [[ ! -e $BITSDIR ]]
    then
        f_info "Creating $BITSDIR directory:"
        mkdir -p $BITSDIR;
        f_verify
    fi
}

#####################################
# MAIN
#####################################
if [ ! -f /tmp/pks_variables ] ; then
    touch /tmp/pks_variables
else
    >/tmp/pks_variables
fi

f_startup_question
f_choice_question

cat /tmp/pks_variables
rm -Rf /tmp/pks_variables

f_info "PKS Client setup COMPLETED - please check logs for details"

