#!/bin/bash

# Tested on Ubuntu 19.04 LTS
# Script will download test cases for PKS,
# download all required images and re-tag them to match Harbor private registry naming ready for testing
# valid for PKS 1.4
# bash -c "$(wget -O - https://raw.githubusercontent.com/agilderdale/pks-env/master/support-scripts/test_cases_prep.sh)"

BINDIR=/usr/local/bin
HARBOR_URL="harbor.mylab.local"
PROJECT_NAME="test"
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
    msg="$*"
    if [ $rc != 0 ] ; then
       if [ -z "$msg" ] ; then
           f_error "Last command - FAILED !!!"
        else
           f_error "$msg"
        fi
        exit 1
    fi
}

f_startup_question() {
    clear
    echo "  ================================================"
    echo "  ================================================"
    echo ""
    echo "  =========== PKS TESTING PREP WORK =============="
    echo ""
    echo "  ================================================"
    echo "      This VM has to be able to access internet"
    echo "  ================================================"
    echo "           This script has to run as root "
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
        echo "  a - prep all environment"
        echo "  h - prep access and trust config to Harbor registry"
        echo "  e - exit"
        echo "*******************************************************************************************"
        read -p "   Select one of the options? (v|a|h|e): " vahe

        case $vahe in
            [Vv]* ) clear;
                    f_verify_cli_tools;
                    ;;
            [Aa]* ) f_init;
                    f_download_git_repos;
                    f_download_docker_images;
                    f_retag_yaml;
                    ;;
            [Hh]* ) f_init;
                    f_config_registry;
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
#    f_info "Updating OS and installing packages"
#    add-apt-repository universe
#    f_verify
#    apt-get update 
#    f_verify
#    apt-get upgrade
#    f_verify

    for pkg in docker openssh-server git apt-transport-https ca-certificates curl software-properties-common build-essential zlibc zlib1g-dev ruby ruby-dev openssl libxslt1-dev libxml2-dev libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 sshpass jq dnsmasq iperf3 sshpass ipcalc curl npm net-tools nodejs
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

    npm list --depth 1 --global vmw-cli > /dev/null 2>&1
    response=`echo $?`

    if [ $response -ne 0 ] ; then
        f_info "Installing vmw-cli tool..."
        # vwm-cli - requires nodejs >=8
        curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
    #    apt-get install -y nodejs
        npm install vmw-cli --global
        f_verify
    else
        f_info "vmw-cli already installed - skipping... "
        npm list --depth 1 --global vmw-cli
    fi
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
    curl -LO https://github.com/pivotal-cf/om/releases/download/${OMRELEASE}/om-linux
    f_verify
    chown root om-linux
    f_verify
    chmod ugo+x om-linux
    f_verify
    mv om-linux ${BINDIR}/om
    f_verify

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
    curl -LO https://github.com/pivotal-cf/pivnet-cli/releases/download/v${PIVNETRELEASE}/pivnet-linux-amd64-${PIVNETRELEASE}
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
    if uaac version 2> /dev/null | grep -q 'UAA client ' ; then version=`uaac version |awk '{print $3}'` ;echo "$version                                    <= UAA CLI       | OK" ; else echo "   UAA CLI FAILED" ;fi
    echo""
    f_info "Installing verify CLI tools - COMPLETED"
    sleep 5
    echo "-------------------------------------------------------------------------------------------"
}

f_download_git_repos() {
    echo "-------------------------------------------------------------------------------------------"
    f_info "Downloading supporting github repo from https://github.com/csaroka/k8s-tc-templates.git"
    if [[ -e /DATA/GIT/k8s-tc-templates/ ]]
    then
        rm -Rf /DATA/GIT/k8s-tc-templates
    else [[ ! -e /DATA/GIT/ ]]
        mkdir -p /DATA/GIT/
    fi
    cd /DATA/GIT/
    git clone https://github.com/csaroka/k8s-tc-templates.git
    f_info "Git repo download - COMPLETED"

}

f_config_registry() {

    echo "-------------------"
    f_info "Checking nslookup install..."
    apt list dnsutils |grep dnsutils > /dev/null 2>&1
    f_verify

    echo "-------------------"
    f_info "Checking ${HARBOR_URL} can be resolved by the server..."
    nslookup ${HARBOR_URL}
    f_verify

    echo "-------------------"
    f_info "Checking DOCKER install..."
    docker ps > /dev/null 2>&1
    f_verify

    echo "-------------------"
    f_info "Checking CURL install..."
    apt list curl |grep curl > /dev/null 2>&1
    f_verify

    echo "-------------------"
    f_info "Downloading ca.crt from Harbor to /tmp/ca.crt..."
    curl https://${HARBOR_URL}/api/systeminfo/getcert -k > /tmp/ca.crt
    grep CERTIFICATE /tmp/ca.crt > /dev/null 2>&1
    f_verify

    echo "-------------------"
    f_info "Checking /etc/docker/certs.d/${HARBOR_URL}/ca.crt ..."
    if [[ ! -f /etc/docker/certs.d/${HARBOR_URL}/ca.crt ]] ; then
        if [[ ! -e /etc/docker/certs.d/${HARBOR_URL} ]] ; then
            f_info "Creating directory for registry certificate /etc/docker/certs.d/${HARBOR_URL} :"
            mkdir -p /etc/docker/certs.d/${HARBOR_URL}
            f_verify
        fi
        cp /tmp/ca.crt /etc/docker/certs.d/${HARBOR_URL}/
        ls /etc/docker/certs.d/${HARBOR_URL}/ca.crt > /dev/null 2>&1
        f_verify
    fi

    echo "-------------------"
    f_info "Checking ~/.docker/tls/${HARBOR_URL}\:4443/ca.crt ..."
    if [[ ! -f ~/.docker/tls/${HARBOR_URL}\:4443/ca.crt ]] ; then
        if [[ ! -e ~/.docker/tls/${HARBOR_URL}\:4443/ ]] ; then
            f_info "Creating directory for Trust certificate ~/.docker/tls/${HARBOR_URL}:4443/ :"
            mkdir -p ~/.docker/tls/${HARBOR_URL}\:4443/
            f_verify
        fi
        cp /tmp/ca.crt ~/.docker/tls/${HARBOR_URL}\:4443/
        ls ~/.docker/tls/${HARBOR_URL}\:4443/ca.crt > /dev/null 2>&1
        f_verify
    fi

    echo "-------------------"
    f_info "Checking ~/.docker/trust/ca.crt ..."
    if [[ ! -f ~/.docker/trust/ca.crt ]] ; then
        if [[ ! -e ~/.docker/trust/ ]] ; then
            f_info "Creating directory for Trust certificate ~/.docker/trust/ :"
            mkdir -p ~/.docker/trust/
        fi
        cp /tmp/ca.crt ~/.docker/trust/
        f_verify
        ls ~/.docker/trust/ca.crt > /dev/null 2>&1
        f_verify
    fi

    echo "-------------------"
    f_info "Checking /usr/local/share/ca-certificates/ca.crt ..."
    if [[ ! -f /usr/local/share/ca-certificates/ca.crt ]] ; then
        f_info "Updating ca-certificates..."
        cp /tmp/ca.crt /usr/local/share/ca-certificates/
        update-ca-certificates
        service docker restart
    fi
}

f_download_docker_images() {
    echo "-------------------"
    f_info "Checking nslookup install..."
    apt list dnsutils |grep dnsutils > /dev/null 2>&1
    f_verify

    echo "-------------------"
    f_info "Checking ${HARBOR_URL} can be resolved by the server..."
    nslookup ${HARBOR_URL}
    f_verify

    f_info "Login to ${HARBOR_URL} private registry. Please type user and then password:"
    docker login $HARBOR_URL
    f_verify "Could not login to $HARBOR_URL registry. CHeck that the URL is correct"

    cd /DATA/GIT/k8s-tc-templates/
    >/tmp/list

    var1=`grep image: *.yaml |awk '{print $3}'`
    var2=`grep image: *.yaml |awk '{print $4}'`

    for i in $var1
    do
        if [[ $i =~ .*image.* ]] || [[ $i =~ .*trustme.* ]] || [[ $i =~ .*project-priv-a.* ]] || [[ $i =~ .*#.* ]] ; then
            echo "this will not be used: $i" > /dev/null 2>&1 # left for testing
        else
            echo "$i" >> /tmp/list
        fi
    done

    for i in $var2
    do
        if [[ $i =~ .*image.* ]] || [[ $i =~ .*trustme.* ]] || [[ $i =~ .*project-priv-a.* ]] || [[ $i =~ .*#.* ]] ; then
            echo "not required: $i" > /dev/null 2>&1 # left for testing
        else
            echo "$i" >> /tmp/list
        fi
    done

    awk '!a[$0]++' /tmp/list > /tmp/list1

    while read -r line
    do
        echo "------------------------"
        f_info "Preparing $line image..."
        docker pull $line
        f_verify "Could not pull the $line image - check if the image name and version is correct!!!"
        docker tag $line ${HARBOR_URL}/${PROJECT_NAME}/$line
        f_verify
        docker push ${HARBOR_URL}/${PROJECT_NAME}/$line
        f_verify "Could not push to registry - check if the ${HARBOR_URL}/${PROJECT_NAME} project exists!!!"
    done < /tmp/list1

}

f_retag_yaml() {
    cp /tmp/list1 /tmp/list2
    sed -i -e 's/\//\\\//g' /tmp/list2
    while read -r line
    do
        sed -i -e "s/${line}/${HARBOR_URL}\/${PROJECT_NAME}\/${line}/g" *.yaml
    done < /tmp/list2
}

f_init(){
    f_input_vars BITSDIR
    f_input_vars HARBOR_URL
    f_input_vars PROJECT_NAME

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

