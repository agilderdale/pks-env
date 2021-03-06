#!/bin/bash

# Created and maintained by Alicja Gilderdale - https://github.com/agilderdale/pks-env.git
# This script is for setting up PKS Client VM from the scratch.
# Only basic Ubuntu image is required - I personally use Ubuntu Desktop version to have browser:
# https://www.ubuntu.com/download/desktop
# Some commands has been used from from pks-prep bdereims@vmware.com
#Tested on Ubuntu 18.04 LTS
# run this script as sudo
# bash -c "$(wget -O - https://raw.githubusercontent.com/agilderdale/pks-env/master/support-scripts/setup-pks-client.sh)"

BINDIR=/usr/local/bin
BOSHRELEASE=6.2.1
HELMRELEASE=2.14.1
OMRELEASE=4.5.0
PIVNETRELEASE=1.0.0
PKSRELEASE=1.5.2
PIVOTALTOKEN=''
BITSDIR="/DATA/packages"


f_info(){
    today=`date +%H:%M:%S`

    echo "[ $today ] INF  ${FUNCNAME[ 1 ]}: $*"
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

f_startup_question() {
    clear
    echo "  ================================================"
    echo "  ================================================"
    echo ""
    echo "  =========== RUN THIS SCRIPT AS SUDO! ==========="
    echo ""
    echo "  ================================================"
    echo ""
    echo "  Welcome to PKS Client configuration!"
    echo "  NOTE: To run the script you need Pivotal Token"
    echo "  Go to user settings to generate the token:"
    echo "  https://login.run.pivotal.io/login"
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
        echo "  v - verify CLI tools"
        echo "  a - install all (pks, bosh, om, kubectl, uaac, om, helm)"
        echo "  p - pks | b - bosh | u - uaac | o - om | h - helm | k - kubectl"
        echo "  e - exit"
        echo "*******************************************************************************************"
        read -p "   Select one of the options? (v|a|p|b|u|o|h|k|e): " vapbuohek

        case $vapbuohek in
            [Vv]* ) clear;
                    f_verify_cli_tools;
                    ;;
            [Aa]* ) f_init;
                    f_install_all;
                    ;;
            [Pp]* ) clear; f_init;
                    f_input_vars PKSRELEASE;
                    f_input_vars_sec PIVOTALTOKEN;
                    f_input_vars PIVNETRELEASE;
                    source /tmp/pks_variables;
                    f_install_packages;
                    f_install_pivnet_cli;
                    f_install_pks_cli;
                    ;;
            [Bb]* ) clear;
                    f_input_vars BOSHRELEASE;
                    f_init;
                    source /tmp/pks_variables;
                    f_install_packages;
                    f_install_bosh_cli;
                    ;;
            [Uu]* ) clear; f_init;
                    source /tmp/pks_variables;
                    f_install_packages;
                    f_install_uaac_cli;
                    ;;
            [Oo]* ) clear; f_init;
                    f_input_vars OMRELEASE;
                    source /tmp/pks_variables;
                    f_install_packages;
                    f_install_om_cli;
                    ;;
            [Hh]* ) clear; f_init;
                    f_input_vars HELMRELEASE;
                    source /tmp/pks_variables;
                    f_install_packages;
                    f_install_helm_cli;
                    ;;
            [Kk]* ) clear; f_init;
                    source /tmp/pks_variables;
                    f_install_packages;
                    f_install_kubectl_cli;
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

    if [[ -z ${!1} ]]
    then
        declare $var=$temp
        echo "export $var=${!var}" >> /tmp/pks_variables
#        cat /tmp/pks_variables
        echo "Set to default: $var="${!var}
    else
#       echo "temp="$temp
        echo "Variable set to: $1 = " ${!1}
        echo "export $1=${!1}" >> /tmp/pks_variables
#       cat /tmp/pks_variables
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
#    echo $1 = ${!1}
    echo "Set: $1 = **************"
    echo "---------------------------"
}

f_install_packages() {

    echo "-------------------------------------------------------------------------------------------"
#   f_info "Updating OS and installing packages"
    add-apt-repository universe
    f_verify
    apt-get update
    f_verify
    apt-get upgrade
    f_verify

    for pkg in docker.io openssh-server git apt-transport-https ca-certificates curl software-properties-common build-essential zlibc zlib1g-dev ruby ruby-dev openssl libxslt1-dev libxml2-dev libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 sshpass jq dnsmasq iperf3 sshpass ipcalc net-tools
    do
        dpkg-query -l $pkg > /dev/null 2>&1
        response=`echo $?`
        if [ $response -ne 0 ] ; then
            apt-get install -y $pkg
        else
            pkg_version=`dpkg-query -l $pkg |grep $pkg |awk '{print $2, $3}'`
            f_info "Already installed => $pkg_version - skippping..."
        fi
    done
#    apt-get install -y docker openssh-server git apt-transport-https ca-certificates curl software-properties-common build-essential
#    apt-get install -y zlibc zlib1g-dev ruby ruby-dev openssl libxslt1-dev libxml2-dev libssl-dev libreadline-dev libyaml-dev libsqlite3-dev
#    apt-get install -y sqlite3 sshpass jq dnsmasq iperf3 sshpass ipcalc curl npm net-tools

    echo "-------------------------------------------------------------------------------------------"

    dpkg-query -l curl > /dev/null 2>&1
    response=`echo $?`
    if [ $response -ne 0 ] ; then
        apt-get install -y curl
        f_verify
    else
        pkg_version=`dpkg-query -l curl |grep curl |awk '{print $2, $3}'`
        f_info "Already installed => $pkg_version - skippping..."
    fi

    dpkg-query -l nodejs > /dev/null 2>&1
    response=`echo $?`
    if [ $response -ne 0 ] ; then
        curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
        apt-get install -y nodejs
        f_verify
    else
        pkg_version=`dpkg-query -l nodejs |grep nodejs |awk '{print $2, $3}'`
        f_info "Already installed => $pkg_version - skippping..."
    fi

    
#    npm list --depth 1 --global vmw-cli > /dev/null 2>&1
#    response=`echo $?`

#    if [ $response -ne 0 ] ; then
#        f_info "Installing vmw-cli tool..."
        # vwm-cli - requires nodejs >=8
#        curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
    #    apt-get install -y nodejs
#        npm install vmw-cli --global
#        f_verify
#    else
#        f_info "vmw-cli already installed - skipping... "
#        npm list --depth 1 --global vmw-cli
#    fi
}


f_install_uaac_cli() {
    echo "-------------------------------------------------------------------------------------------"

    gem list uaac > /dev/null 2>&1
    response=`echo $?`

    if [ $response -ne 0 ] ; then
        f_info "Installing UAAC tool..."
        # uuac
        gem install cf-uaac
        f_verify
    else
        f_info "UAAC tool Already installed - skipping..."
        gem list uaac |grep cf-uaac
    fi
}

f_install_kubectl_cli() {
    echo "-------------------------------------------------------------------------------------------"
    if kubectl version 2> /dev/null | grep -q 'Client Version:'
    then
        version=`kubectl version 2>/dev/null |awk '{print $5}'`
        echo "$version                    <= kubectl CLI   | OK"
    else
        echo "   kubectl CLI FAILED" ;fi

    f_info "Installing kubectl CLI"
    # kubectl
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    f_verify
    chmod +x kubectl
    f_verify
    cp kubectl $BINDIR/kubectl
    f_verify
    rm kubectl
    f_verify
}

f_install_bosh_cli() {
    echo "-------------------------------------------------------------------------------------------"
    f_info "Installing bosh CLI"
    # bosh
    curl -LO https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${BOSHRELEASE}-linux-amd64
    f_verify
    cp bosh-cli-${BOSHRELEASE}-linux-amd64 ${BINDIR}/bosh
    f_verify
    chmod ugo+x ${BINDIR}/bosh
    f_verify
    rm bosh-cli-${BOSHRELEASE}-linux-amd64
    f_verify

    f_info "Installing bosh CLI - COMPLETED"
}

f_install_om_cli() {
    echo "-------------------------------------------------------------------------------------------"
    f_info "Installing OpsManager CLI"
    # om
    mkdir -p ${BITSDIR}/om-release
    cd ${BITSDIR}/om-release
    curl -LO https://github.com/pivotal-cf/om/releases/download/${OMRELEASE}/om-linux-${OMRELEASE}.tar.gz
    f_verify
    tar -xzvf om-linux-${OMRELEASE}.tar.gz
    chown root om
    f_verify
    chmod ugo+x om
    f_verify
    mv om ${BINDIR}/om
    f_verify
    cd ${BITSDIR}
    rm -Rf ${BITSDIR}/om-release
    f_info "Installing om CLI - COMPLETED"
}

f_install_helm_cli() {
    echo "-------------------------------------------------------------------------------------------"
    f_info "Installing Helm CLI"
    # helm
    curl -LO https://kubernetes-helm.storage.googleapis.com/helm-v${HELMRELEASE}-linux-amd64.tar.gz
    f_verify
    tar xvzf helm-v${HELMRELEASE}-linux-amd64.tar.gz linux-amd64/helm
    f_verify
    chmod +x linux-amd64/helm
    f_verify
    cp linux-amd64/helm ${BINDIR}/helm
    f_verify
    rm -fr linux-amd64
    f_verify
    rm helm-v${HELMRELEASE}-linux-amd64.tar.gz
    f_verify

    f_info "Installing helm CLI - COMPLETED"
}

f_install_pivnet_cli() {
    echo "-------------------------------------------------------------------------------------------"
    f_info "Installing pivnet CLI"
    # pivnet cli
    curl -LO https://github.com/pivotal-cf/pivnet-cli/releases/download/v${PIVNETRELEASE}/pivnet-linux-amd64-${PIVNETRELEASE} -k
    f_verify

    chown root pivnet-linux-amd64-${PIVNETRELEASE}
    f_verify
    chmod ugo+x pivnet-linux-amd64-${PIVNETRELEASE}
    f_verify
    mv pivnet-linux-amd64-${PIVNETRELEASE} ${BINDIR}/pivnet
    f_verify

    f_info "Installing pivnet CLI - COMPLETED"
}

f_install_pks_cli() {
    # pks cli
    pivnet login --api-token=$PIVOTALTOKEN
    f_verify
    PKSFileID=`pivnet pfs -p pivotal-container-service -r $PKSRELEASE | grep 'PKS CLI - Linux' | awk '{ print $2}'`
    pivnet download-product-files -p pivotal-container-service -r $PKSRELEASE -i $PKSFileID
    f_verify

    mv pks-linux-amd64* pks
    f_verify
    chown root:root pks
    f_verify
    chmod +x pks
    f_verify
    cp pks ${BINDIR}/pks
    f_verify

    f_info "Installing pks CLI - COMPLETED"
}

f_verify_cli_tools() {
    echo "-------------------------------------------------------------------------------------------"
    f_info "Verifying installed CLI tools"
    if pks --version 2> /dev/null | grep -q 'PKS CLI version' ; then version=`pks --version |awk '{print $4}'` ; echo "$version                          <= PKS CLI       | OK" ; else echo "   PKS CLI FAILED" ;fi
    if kubectl version 2> /dev/null | grep -q 'Client Version:' ; then version=`kubectl version 2>/dev/null |awk '{print $5}'` ; echo "$version                    <= kubectl CLI   | OK" ; else echo "   kubectl CLI FAILED" ;fi
    if om version 2> /dev/null | grep -q .[0-9]* ; then version=`om version 2> /dev/null` ; echo "$version                                   <= OM CLI        | OK" ; else echo "   OM CLI FAILED" ;fi
    if bosh -version 2> /dev/null | grep -q 'version' ; then version=`bosh -version |awk '{print $2}'` ; echo "$version      <= BOSH CLI      | OK" ; else echo "   OM CLI FAILED" ;fi
#    if uaac version 2> /dev/null | grep -q 'UAA client ' ; then version=`uaac version |awk '{print $3}'` ;echo "$version                                    <= UAA CLI       | OK" ; else echo "   UAA CLI FAILED" ;fi
    echo""
    f_info "Installing verify CLI tools - COMPLETED"
    sleep 5
    echo "-------------------------------------------------------------------------------------------"
}

f_download_git_repos() {
    echo "-------------------------------------------------------------------------------------------"
    f_info "Downloading supporting github repos"
    if [[ ! -e /DATA/GIT-REPOS ]]; then
        mkdir -p /DATA/GIT-REPOS/
    fi

    git clone https://github.com/bdereims/pks-prep.git
    git clone https://github.com/vmware/nsx-t-datacenter-ci-pipelines.git
    git clone https://github.com/sparameswaran/nsx-t-ci-pipeline.git
    f_info "Download git repos - COMPLETED"

}

f_install_all() {

    f_input_vars BOSHRELEASE
    f_input_vars HELMRELEASE
 #   f_input_vars OMRELEASE
    f_input_vars PIVNETRELEASE
    f_input_vars PKSRELEASE
    f_input_vars_sec PIVOTALTOKEN

    source /tmp/pks_variables

    f_install_packages
#    f_install_uaac_cli
    f_install_kubectl_cli
    f_install_bosh_cli
    f_install_om_cli
    f_install_pivnet_cli
    f_install_helm_cli
    f_install_pks_cli

    f_download_git_repos
    f_verify_cli_tools

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

