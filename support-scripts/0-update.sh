#!/bin/bash
# This script contains commands from 0-update.sh script from bdereims@vmware.com
#Only tested on Ubuntu 16.04/18.04 LTS
# run this script as sudo

f_info(){
    today=`date +%Y-%m-%d.%H:%M:%S`

    echo "***************************************************************"
    echo "[ $today ]  INFO  $*"
    echo "***************************************************************"
}

f_startup_question() {
    echo "***************************************************************"
    echo "RUN THIS SCRIPT AS SUDO!"
    echo "***************************************************************"
    echo "Welcome to PKS Client configuration steps!"
    echo "Note: In order to run the script you will need Pivotal Token generated."
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
    echo "***************************************************************"
    echo "What would you like to do today?"
    echo "Menu:"
    echo "v - verify CLI tools"
    echo "a - Install all - pks, bosh, om, kubectl, uaac, om, helm"
    echo "p - pks ; b - bosh; u - uaac; o - om; h - helm; k - kubectl"
    echo "e - exit"
    echo "***************************************************************"
    while true; do
        read -p "Do you wish to start? (v|a|p|b|u|o|h|k|d)" vapbuohek
        case $vapbuohek in
            [Vv]* ) f_verify_cli_tools;
                    break;;
            [Aa]* ) f_install_all;
                    break;;
            [Pp]* ) f_prep_vars;
                    f_input_vars PKSRELEASE 1.2.0;
                    f_input_vars_sec PIVOTALTOKEN;
                    f_input_vars PIVNETRELEASE 0.0.55;
                    f_install_pivnet_cli;
                    f_install_pks_cli;
                    break;;
            [Bb]* ) f_prep_vars;
                    f_input_vars BOSHRELEASE 5.3.1;
                    f_install_bosh_cli;
                    break;;
            [Uu]* ) f_prep_vars;
                    f_install_uaac_cli;
                    break;;
            [Oo]* ) f_prep_vars;
                    f_input_vars OMRELEASE 0.42.0;
                    f_install_om_cli;
                    break;;
            [Hh]* ) f_prep_vars;
                    f_input_vars HELMRELEASE 2.11.0;
                    f_install_helm_cli;
                    break;;
            [Kk]* ) f_prep_vars;
                    f_install_kubectl_cli;
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


f_install_uaac_cli() {
    f_info "Installing UAAC tool"
    # uuac
    gem install cf-uaac
}

f_install_kubectl_cli() {
    f_info "Installing kubectl CLI"
    # kubectl
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x kubectl
    cp kubectl $BINDIR/kubectl
    rm kubectl
}

f_install_bosh_cli() {
    f_info "Installing bosh CLI"
    # bosh
    curl -LO https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${BOSHRELEASE}-linux-amd64
    cp bosh-cli-${BOSHRELEASE}-linux-amd64 ${BINDIR}/bosh
    chmod ugo+x ${BINDIR}/bosh
    rm bosh-cli-${BOSHRELEASE}-linux-amd64
}

f_install_om_cli() {
    f_info "Installing OpsManager CLI"
    # om
    curl -LO https://github.com/pivotal-cf/om/releases/download/${OMRELEASE}/om-linux
    chown root om-linux
    chmod ugo+x om-linux
    mv om-linux ${BINDIR}/om
}

f_install_helm_cli() {
    f_info "Installing Helm CLI"
    # helm
    curl -LO https://kubernetes-helm.storage.googleapis.com/helm-v${HELMRELEASE}-linux-amd64.tar.gz
    tar xvzf helm-v${HELMRELEASE}-linux-amd64.tar.gz linux-amd64/helm
    chmod +x linux-amd64/helm
    cp linux-amd64/helm ${BINDIR}/helm
    rm -fr linux-amd64
    rm helm-v${HELMRELEASE}-linux-amd64.tar.gz
}


f_install_pivnet_cli() {
    f_info "Installing pivnet CLI"
    # pivnet cli
    curl -LO https://github.com/pivotal-cf/pivnet-cli/releases/download/v${PIVNETRELEASE}/pivnet-linux-amd64-${PIVNETRELEASE}

    chown root pivnet-linux-amd64-${PIVNETRELEASE}
    chmod ugo+x pivnet-linux-amd64-${PIVNETRELEASE}
    mv pivnet-linux-amd64-${PIVNETRELEASE} ${BINDIR}/pivnet
}

f_install_pks_cli() {
    # pks cli
    pivnet login --api-token=$PIVOTALTOKEN
    PKSFileID=`pivnet pfs -p pivotal-container-service -r $PKSRELEASE | grep 'PKS CLI - Linux' | awk '{ print $2}'`
    pivnet download-product-files -p pivotal-container-service -r $PKSRELEASE -i $PKSFileID

    mv pks-linux-amd64* pks
    chown root:root pks
    chmod +x pks
    cp pks ${BINDIR}/pks
}

f_verify_cli_tools() {

    f_info "Verifying installed CLI tools"
    if pks --version 2> /dev/null | grep -q 'PKS CLI version' ; then echo "PKS CLI - OK" ; else echo "PKS CLI FAILED" ;fi
    if kubectl version 2> /dev/null | grep -q 'Client Version:' ; then echo "kubectl CLI - OK" ; else echo "kubectl CLI FAILED" ;fi
    if om version 2> /dev/null | grep -q .[0-9]* ; then echo "OM CLI - OK" ; else echo "OM CLI FAILED" ;fi
    if bosh -version 2> /dev/null | grep -q 'version' ; then echo "BOSH CLI - OK" ; else echo "OM CLI FAILED" ;fi
    if uaac version 2> /dev/null | grep -q 'UAA client ' ; then echo "UAA CLI - OK" ; else echo "UAA CLI FAILED" ;fi
}

f_download_git_repos() {

    f_info "Downloading supporting github repos"
    if [[ ! -e /DATA/GIT-REPOS ]]; then
        mkdir -p /DATA/GIT-REPOS/
    fi

    git clone https://github.com/bdereims/pks-prep.git
    git clone https://github.com/vmware/nsx-t-datacenter-ci-pipelines.git
    git clone https://github.com/sparameswaran/nsx-t-ci-pipeline.git

}

f_install_all() {

    f_input_vars BOSHRELEASE 5.3.1
    f_input_vars HELMRELEASE 2.11.0
    f_input_vars OMRELEASE 0.42.0
    f_input_vars PIVNETRELEASE 0.0.55
    f_input_vars BITSDIR /DATA/bits
    f_input_vars PKSRELEASE 1.2.0
    f_input_vars_sec PIVOTALTOKEN

    if [[ ! -e $BITSDIR ]]; then
        mkdir $BITSDIR
    fi

    f_install_packages
    f_install_uaac_cli
    f_install_kubectl_cli
    f_install_bosh_cli
    f_install_om_cli
    f_install_pivnet_cli
    f_install_helm_cli
    f_install_pks_cli

    f_download_git_repos
    f_verify_cli_tools

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

