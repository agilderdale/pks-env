#!/bin/bash
# Created and maintained by Alicja Gilderdale - https://github.com/agilderdale/pks-env.git
# This script is for setting up concourse pipeline to run NSX-T and PKS install and config.
#Tested on Ubuntu 18.04 LTS
# run this script as sudo
# bash -c "$(wget -O - https://raw.githubusercontent.com/agilderdale/pks-env/master/support-scripts/setup-pipelines.sh)"


BINDIR=/usr/local/bin
#BITSDIR=/DATA/bits
CONCOURSE_IP=''
EXTERNAL_DNS=''
VMWARE_USER=''
VMWARE_PASSWORD=''
NSXT_VERSION=2.3
CONFIG_DIR='/DATA/GIT-REPOS/pks-env/config_files/home-lab'

f_banner(){
    today=`date +%d-%m-%y_%H:%M:%S`

    echo "*******************************************************************************************"
    echo "[ $today ]  ${FUNCNAME[ 1 ]}: $*"
    echo "*******************************************************************************************"
}

f_info(){
    today=`date +%H:%M:%S`

    echo "-------------------------------------------------------------------------------------------"
    echo "[ $today ] INF  ${FUNCNAME[ 1 ]}: $*"
    echo "-------------------------------------------------------------------------------------------"
}

f_error(){
    today=`date +%Y-%m-%d.%H:%M:%S`

    echo "-------------------------------------------------------------------------------------------"
    echo "[ $today ] ERR  ${FUNCNAME[ 1 ]}: $*"
    echo "-------------------------------------------------------------------------------------------"
}

f_verify(){
    rc=`echo $?`
    if [ $rc != 0 ] ; then
        f_error "Last command - FAILED !!!"
        exit 1
    fi
}

f_intro() {
    clear
    echo "  ====================================================="
    echo "  ====================================================="
    echo ""
    echo "  ============== RUN THIS SCRIPT AS SUDO! ============="
    echo ""
    echo "  ====================================================="
    echo ""
    echo "  Welcome to SETUP CONCOURSE PIPELINE script!"
    echo ""
    echo "  ====================================================="
    echo ""
    while true; do
        read -p "    Do you wish to continue? (y/n): " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo "            =============="
                    echo "               GOODBYE!"
                    echo "            =============="
                    exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    echo "    ========================================"

}

f_main_menu() {
    clear
    while true; do
        echo "*******************************************************************************************"
        echo "  What would you like to do today?"
        echo "*******************************************************************************************"
        echo "  Available options:"
        echo "  p - setup PKS and NSX-T pipelines"
        echo "  t - test variables"
        echo "  c - clean up docker"
        echo "  o - download ovftool"
        echo "  n - download nsx-t-appliance 2.3"
        echo "  e - exit"
        echo "*******************************************************************************************"
        read -p "   Select one of the options? (p|e|t|c|o|n): " petcon

        case $petcon in
            [Nn]* ) clear;
                    f_init;
                    f_install_packages;
                    f_download_nsx;
                    ;;
            [Oo]* ) clear;
                    f_init;
                    f_install_packages;
                    f_download_ovftool;
                    ;;
            [Pp]* ) clear;
                    f_init;
                    f_install_packages;
                    f_download_vmmare_repo;
                    f_start_docker;
                    ;;
            [Tt]* ) clear;
                    f_init;
                    ;;
            [Cc]* ) clear;
                    f_clean_docker;
                    break;;
            [Ee]* ) exit;;
            * ) echo "Please answer one of the available options";;
        esac

        f_info "Following variables have been used:"
        cat /tmp/pks_variables

        rm -Rf /tmp/.secret >/dev/null

        f_info "Pipeline task - COMPLETED"
        sleep 5

    done
    echo "*******************************************************************************************"

}

f_input_vars() {

    if [ -f /tmp/pks_variables_old ] ; then
        source /tmp/pks_variables_old
    fi

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
    echo "-------------------------------------------------------------------------------------------"
}

f_input_vars_sec(){

    if [ ! -f /tmp/.secret ] ; then
        touch /tmp/secret
    fi

    var=$1
    unset password
    echo -n "$1: "
    while IFS= read -p "$prompt" -r -s -n 1 char
    do
        # Enter - accept password
        if [[ $char == $'\0' ]] ; then
            break
        fi
        # Backspace
        if [[ $char == $'\177' ]] ; then
            prompt=$'\b \b'
            password="${password%?}"
        else
            prompt='*'
            password+="$char"
        fi
    done

    declare $var=$password

    if [[ -z ${!1} ]]
    then
        f_error "The $1 variable has no default value!!! User input is required - EXITING! "
        exit 1
    fi

    echo ""
    echo "export $1=${!1}" > /tmp/.secret
    echo "Set: $1 = [ secret ]"
    echo "-------------------------------------------------------------------------------------------"

}

#f_input_vars_sec() {
#
#
#    read -sp "$1: " $1
#    echo
#    if [[ -z ${!1} ]]
#    then
#        f_error "The $1 variable has no default value!!! User input is required - EXITING! "
#        exit 1
#    fi
#    echo "Set: $1 = **************"
#    echo "-------------------------------------------------------------------------------------------"
#}

f_install_packages() {

    f_banner ""
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

    f_banner ""
    wget https://github.com/vmware/nsx-t-datacenter-ci-pipelines/raw/master/docker_image/nsx-t-install-09122018.tar -O nsx-t-install.tar
    docker load -i nsx-t-install.tar
    f_verify
    mkdir -p /home/concourse

    f_info "Downloading supporting github repos"
    if [[ ! -e /DATA/GIT-REPOS ]]; then
        mkdir -p /DATA/GIT-REPOS/
    fi

    cd /DATA/GIT-REPOS
    git clone https://github.com/agilderdale/pks-env.git
    git clone https://github.com/vmware/nsx-t-datacenter-ci-pipelines.git
    git clone https://github.com/sparameswaran/nsx-t-ci-pipeline.git

    cp ${CONFIG_DIR}/*.yml /home/concourse/
}

f_download_ovftool(){
    source /tmp/pks_variables
    source /tmp/.secret

    cd /home/concourse
    vmw-cli index OVFTOOL430
    vmw-cli get VMware-ovftool-4.3.0-7948156-lin.x86_64.bundle
}

f_download_nsx(){
    source /tmp/pks_variables
    source /tmp/.secret

    cd /home/concourse
    vmw-cli index NSX-T-230
    vmw-cli get nsx-unified-appliance-2.3.0.0.0.10085405.ova
}

f_start_docker(){

    f_banner ""
    source /tmp/pks_variables
    source /tmp/.secret

    docker run --name nsx-t-install -d \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /home/concourse:/home/concourse \
      -e CONCOURSE_URL="http://${CONCOURSE_IP}:8080" \
      -e EXTERNAL_DNS="$EXTERNAL_DNS" \
      -e IMAGE_WEBSERVER_PORT=40001 \
      -e VMWARE_USER="$VMWARE_USER" \
      -e VMWARE_PASSWORD="$VMWARE_PASSWORD" \
      -e NSXT_VERSION="$NSXT_VERSION" \
      nsx-t-install

      f_banner "
                     nsx-t-install docker container has been launched. Exit this script and type:

                     $ docker ps -a

                     All available containers will list on the screen.
                     If the nsx-t-install container is shown as stopped, check logs with the command below:

                     $ docker logs <container ID>
              "
       sleep 5
}

f_clean_docker(){

    f_banner ""

    for i in nsx-t-install vmw-cli concourse_concourse-worker concourse_concourse-web concourse_concourse-db
    do
        var1=`docker ps -a |grep $i |awk '{print $1}'`
        if [ ! -z $var1 ] ; then
            f_info "Removing $i container..."
            docker rm -f $i
            f_verify
        else
            f_info "$i container does not exist - SKIPPING..."
        fi
    done
}


f_init(){

    f_banner ""
#    f_input_vars BITSDIR
#    CONCOURSE_IP=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
    f_input_vars CONCOURSE_IP
    f_input_vars EXTERNAL_DNS
    f_input_vars NSXT_VERSION
    f_input_vars CONFIG_DIR
    f_input_vars VMWARE_USER
    f_input_vars_sec VMWARE_PASSWORD

    source /tmp/pks_variables
    source /tmp/.secret

#    if [[ ! -e $BITSDIR ]]
#    then
#        f_info "Creating $BITSDIR directory:"
#        mkdir -p $BITSDIR;
#        f_verify
#    fi
}

#####################################
# MAIN
#####################################
rm -Rf /tmp/.secret >/dev/null

if [ ! -f /tmp/pks_variables ] ; then
    touch /tmp/pks_variables
else
    cp /tmp/pks_variables /tmp/pks_variables_old
    >/tmp/pks_variables
fi

f_intro
f_main_menu

