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

    echo "-------------------"
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
        echo "  u - PKS user access - create UAAC admin and dev user roles for PKS CLI"
        echo "  c - Create K8s Cluster"
        echo "  b - Configure access to BOSH CLI on the client VM"
        echo "  e - exit"
        echo "*******************************************************************************************"
        read -p "   Select one of the options? (v|a|h|u|c|b|e): " vahucbe

        case $vahucbe in
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
            [Uu]* ) f_init;
                    f_config_local_uaac;
                    ;;
            [Cc]* ) f_init;
                    f_create_k8s_cluster;
                    ;;
            [Bb]* ) f_init;
                    f_configure_bosh_env;
                    ;;
            [Ee]* ) exit;;
            * ) echo "Please answer one of the available options";;
        esac
    done
    echo "*******************************************************************************************"

}

f_input_vars() {

    COMMENT="$2"

    if [ -f /tmp/pks_variables_old ] ; then
        source /tmp/pks_variables_old
    fi

    var=$1
    temp=${!1}
    if [ ! -z "$COMMENT" ] ; then
        echo "$COMMENT"
    fi
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

f_input_vars_old() {
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

    f_input_vars HARBOR_URL
    f_input_vars PROJECT_NAME

    source /tmp/pks_variables

    if [ -f /tmp/.secret ] ; then
        source /tmp/.secret
    fi

    f_info "Checking nslookup install..."
    apt list dnsutils |grep dnsutils > /dev/null 2>&1
    f_verify

    f_info "Checking ${HARBOR_URL} can be resolved by the server..."
    nslookup ${HARBOR_URL}
    f_verify

    f_info "Checking DOCKER install..."
    docker ps > /dev/null 2>&1
    f_verify

    f_info "Checking CURL install..."
    apt list curl |grep curl > /dev/null 2>&1
    f_verify

    f_info "Downloading ca.crt from Harbor to /tmp/ca.crt..."
    curl https://${HARBOR_URL}/api/systeminfo/getcert -k > /tmp/ca.crt
    grep CERTIFICATE /tmp/ca.crt > /dev/null 2>&1
    f_verify

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

    f_info "Checking /usr/local/share/ca-certificates/ca.crt ..."
    if [[ ! -f /usr/local/share/ca-certificates/ca.crt ]] ; then
        f_info "Updating ca-certificates..."
        cp /tmp/ca.crt /usr/local/share/ca-certificates/
        update-ca-certificates
        service docker restart
    fi
}

f_download_docker_images() {
    f_info "Checking nslookup install..."
    apt list dnsutils |grep dnsutils > /dev/null 2>&1
    f_verify

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

# not in use!!
f_install_go() {
    curl -O https://storage.googleapis.com/golang/go1.11.2.linux-amd64.tar.gz
    tar -xvf go1.11.2.linux-amd64.tar.gz
    mv go /usr/local/bin/
    export GOROOT=$HOME/go
    export GOPATH=$HOME/work
    export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
    mkdir $GOROOT $GOPATH
}



f_SC05-TC03_content_trust() {
    f_info "Test Case: Container Registry Content Trust"

    f_info "Checking wget install..."
    apt list wget |grep wget > /dev/null 2>&1
    f_verify "wget is missing - run 'apt install wget' and rerun the script"

    f_info "Downloading harborctl tool..."
    cd /tmp/
    wget https://github.com/moooofly/harborctl/releases/download/v1.1.0/harborctl_1.1.0_Linux_x86_64.tar.gz
    tar -xzvf harborctl_1.1.0_Linux_x86_64.tar.gz
    chmod 755 /tmp/harborctl
    mv harborctl $BINDIR/

    f_info "Login to $HARBOR_URL..."
}

f_om_validation() {
    # Requires API uri input as first value
    API_CALL="$1"
    f_info "Checking all CLI tools are installed ..."
    if om version 2> /dev/null | grep -q .[0-9]* ; then version=`om version 2> /dev/null` ; echo "$version                                   <= OM CLI        | OK" ; else f_error "   OM CLI FAILED" ;fi

    OPSMAN_URL=opsman.mylab.local
    OPSMAN_ADMIN=admin
    PKS_API_URL=api.mylab.local

    f_input_vars OPSMAN_URL
    f_input_vars OPSMAN_ADMIN
    f_input_vars_sec OPSMAN_PASSWORD
    om -t https://${OPSMAN_URL} -u "${OPSMAN_ADMIN}" -p "${OPSMAN_PASSWORD}" -k curl -p ${API_CALL} -s > /dev/null 2>&1
    resp=$?
    if [ $resp != 0 ] ; then
        f_info "Could not verify connection to OPSMANAGER with URL and credentials provided.
                Try to set OPSMAN_URL as IP if DNS does not work and re-enter user and password:"
        f_input_vars OPSMAN_URL
        f_input_vars OPSMAN_ADMIN
        f_input_vars_sec OPSMAN_PASSWORD
        om -t https://${OPSMAN_URL} -u "${OPSMAN_ADMIN}" -p "${OPSMAN_PASSWORD}" -k curl -p ${API_CALL} -s > /dev/null 2>&1
        f_verify "Wrong information for the provided variables. Please verify and try again later!!!"
    fi

}

f_config_local_uaac() {
    OPSMAN_URL=opsman.mylab.local
    OPSMAN_ADMIN=admin
    PKS_API_URL=api.mylab.local
    DEV_USER=dev-user1
    ADMIN_USER=admin-user1

    f_om_validation /api/v0/deployed/products

#    f_info "Checking all CLI tools are installed ..."
#    if om version 2> /dev/null | grep -q .[0-9]* ; then version=`om version 2> /dev/null` ; echo "$version                                   <= OM CLI        | OK" ; else f_error "   OM CLI FAILED" ;fi


#    f_input_vars OPSMAN_URL
#    f_input_vars OPSMAN_ADMIN
#    f_input_vars_sec OPSMAN_PASSWORD
#    om -t https://${OPSMAN_URL} -u "${OPSMAN_ADMIN}" -p "${OPSMAN_PASSWORD}" -k curl -p /api/v0/deployed/products -s > /dev/null 2>&1
#    resp=$?
#    if [ $resp != 0 ] ; then
#        f_info "Could not verify connection to OPSMANAGER with URL and credentials provided.
#                Try to set OPSMAN_URL as IP if DNS does not work and re-enter user and password:"
#        f_input_vars OPSMAN_URL
#        f_input_vars OPSMAN_ADMIN
#        f_input_vars_sec OPSMAN_PASSWORD
#        om -t https://${OPSMAN_URL} -u "${OPSMAN_ADMIN}" -p "${OPSMAN_PASSWORD}" -k curl -p /api/v0/deployed/products -s > /dev/null 2>&1
#        f_verify "Wrong information for the provided variables. Please verify and try again later!!!"
#    fi

    if bosh -version 2> /dev/null | grep -q 'version' ; then version=`bosh -version |awk '{print $2}'` ; echo "$version      <= BOSH CLI      | OK" ; else f_error "   OM CLI FAILED" ;fi
    if uaac version 2> /dev/null | grep -q 'UAA client ' ; then version=`uaac version |awk '{print $3}'` ;echo "$version                                    <= UAA CLI       | OK" ; else f_error "   UAA CLI FAILED" ;fi

    f_input_vars PKS_API_URL
    f_input_vars DEV_USER
    f_input_vars_sec DEV_USER_PASSWORD
    f_input_vars ADMIN_USER
    f_input_vars_sec ADMIN_USER_PASSWORD

    source /tmp/pks_variables

    if [ -f /tmp/.secret ] ; then
        source /tmp/.secret
    fi

    echo "GUID=$(om -t https://${OPSMAN_URL} -u "${OPSMAN_ADMIN}" -p "${OPSMAN_PASSWORD}" -k curl -p /api/v0/deployed/products -s | jq '.[] | select(.installation_name | contains("pivotal-container-service"))  | .guid' | tr -d '""')"
    GUID=$(om -t https://${OPSMAN_URL} -u "${OPSMAN_ADMIN}" -p "${OPSMAN_PASSWORD}" -k curl -p /api/v0/deployed/products -s | jq '.[] | select(.installation_name | contains("pivotal-container-service"))  | .guid' | tr -d '""')
    echo "ADMIN_SECRET=$(om -t https://${OPSMAN_URL} -u "${OPSMAN_ADMIN}" -p "${OPSMAN_PASSWORD}" -k curl -p /api/v0/deployed/products/${GUID}/credentials/.properties.pks_uaa_management_admin_client -s | jq '.credential.value.secret' | tr -d '""')"
    ADMIN_SECRET=$(om -t https://${OPSMAN_URL} -u "${OPSMAN_ADMIN}" -p "${OPSMAN_PASSWORD}" -k curl -p /api/v0/deployed/products/${GUID}/credentials/.properties.pks_uaa_management_admin_client -s | jq '.credential.value.secret' | tr -d '""')

    uaac target https://${PKS_API_URL}:8443 --skip-ssl-validation
    f_verify
    uaac token client get admin -s "${ADMIN_SECRET}"
    f_verify
    # Deleting the users if they already exist - clean card
    uaac user delete $DEV_USER > /dev/null 2>&1
    uaac user delete $ADMIN_USER > /dev/null 2>&1

    f_info "Creating $DEV_USER ..."
    uaac user add $DEV_USER --emails vmware@${PKS_API_URL} -p ${DEV_USER_PASSWORD}
    f_verify

    f_info "Assign $DEV_USER to pks.clusters.manage role ..."
    uaac member add pks.clusters.manage $DEV_USER
    f_verify

    f_info "Creating $ADMIN_USER ..."
    uaac user add $ADMIN_USER --emails demo@${PKS_API_URL} -p ${ADMIN_USER_PASSWORD}
    f_verify

    f_info "Assign $ADMIN_USER to pks.clusters.admin role ..."
    uaac member add pks.clusters.admin $ADMIN_USER
    f_verify

    f_info "Testing login to the PKS CLI as $ADMIN_USER..."
    pks login -a https://${PKS_API_URL} -u $ADMIN_USER -p $ADMIN_USER_PASSWORD -k
    f_verify

    f_info "Display clusters as $ADMIN_USER..."
    pks clusters
    f_verify

    f_info "Testing login to the PKS CLI as $DEV_USER..."
    pks login -a https://${PKS_API_URL} -u $DEV_USER -p $DEV_USER_PASSWORD -k
    f_verify

    f_info "Display clusters as $DEV_USER..."
    pks clusters
    f_verify
}

#f_config_k8s_user_local() {
#    /DATA/GIT/k8s-tc-templates
#
#}

f_create_k8s_cluster(){

    f_info "Checking all CLI tools are installed ..."
    if om version 2> /dev/null | grep -q .[0-9]* ; then version=`om version 2> /dev/null` ; echo "$version                                   <= OM CLI        | OK" ; else f_error "   OM CLI FAILED" ;fi
    if bosh -version 2> /dev/null | grep -q 'version' ; then version=`bosh -version |awk '{print $2}'` ; echo "$version      <= BOSH CLI      | OK" ; else f_error "   OM CLI FAILED" ;fi
    if uaac version 2> /dev/null | grep -q 'UAA client ' ; then version=`uaac version |awk '{print $3}'` ;echo "$version                                    <= UAA CLI       | OK" ; else f_error "   UAA CLI FAILED" ;fi

    PKS_API_URL=api.mylab.local
    f_input_vars PKS_API_URL
    f_input_vars ADMIN_USER
    f_input_vars_sec ADMIN_USER_PASSWORD

    source /tmp/pks_variables

    if [ -f /tmp/.secret ] ; then
        source /tmp/.secret
    fi
    pks network-profiles |grep medium > /dev/null 2>&1
    resp=$?
    if [ $resp != 0 ] ; then
        f_info "Creating MEDIUM network profile..."
        echo "{ \"name\": \"lb-profile-medium\", \"description\": \"Network profile for MEDIUM size NSX-T load balancer\", \"parameters\": { \"lb_size\": \"medium\" } }" > /tmp/lb-medium.json
        pks create-network-profile /tmp/lb-medium.json
        f_verify
    fi

    f_info "Logging to PKS CLI as $ADMIN_USER :"
    pks login -a https://${PKS_API_URL} -u ${ADMIN_USER} -p ${ADMIN_USER_PASSWORD} -k
    f_verify
    pks network-profiles
    pks plans
    f_info "From the information above specify number of nodes and plan to create used to create K8s cluster:"
    f_input_vars WORKER_NODES
    f_input_vars CLUSTER_PLAN
    f_input_vars NETWORK_PROFILE
    f_input_vars CLUSTER_NAME
    f_input_vars CLUSTER_HOST_NAME

    source /tmp/pks_variables

    f_info "Following command will run:"
    echo "pks create-cluster ${CLUSTER_NAME} --external-hostname ${CLUSTER_HOST_NAME} --plan ${CLUSTER_PLAN} --num-nodes ${WORKER_NODES} --network-profile ${NETWORK_PROFILE}"
    pks login -a https://${PKS_API_URL} -u ${ADMIN_USER} -p ${ADMIN_USER_PASSWORD} -k
    pks create-cluster ${CLUSTER_NAME} --external-hostname ${CLUSTER_HOST_NAME} --plan ${CLUSTER_PLAN} --num-nodes ${WORKER_NODES} --network-profile ${NETWORK_PROFILE}

}

f_configure_bosh_env() {

    f_info "Checking all CLI tools are installed ..."
    if bosh -version 2> /dev/null | grep -q 'version' ; then version=`bosh -version |awk '{print $2}'` ; echo "$version      <= BOSH CLI      | OK" ; else f_error "   OM CLI FAILED" ;fi

    f_om_validation /api/v0/deployed/products
    # USER : director
    # PASSWD : https://OPS-MANAGER-FQDN/api/v0/deployed/director/credentials/director_credentials

    source /tmp/pks_variables

    f_info "Downloading Root CA Cert ..."
    om -t https://10.173.61.130 -u admin -p VMware1! -k curl -p /api/v0/certificate_authorities -s | jq -r '.certificate_authorities | select(map(.active == true))[0] | .cert_pem' > /tmp/root_ca_certificate
    (ls ~/.bosh/root_ca_certificate >> /dev/null 2>&1 && RESULT="yes") || RESULT="no"
    if [[ $RESULT="yes" ]] ; then
        f_info "Certificate already exist - validating ~/.bosh/root_ca_certificate..."
        if ! diff -q ~/.bosh/root_ca_certificate  /tmp/root_ca_certificate &>/dev/null; then
            >&2 echo "different"
            f_info "Existing vertificate is invalid - moving new one to ~/.bosh/root_ca_certificate..."
            DATE=`date +%F`
            mv ~/.bosh/root_ca_certificate_${DATE}
            mv /tmp/root_ca_certificate ~/.bosh/root_ca_certificate
            f_verify
            f_info "Note: Old certificate has been archived to ~/.bosh/root_ca_certificate_${DATE}..."
        else
            f_info "Root CA Cert exists and is valid..."
        fi
    else
        (ls ~/.bosh >> /dev/null 2>&1 && RESULT="yes") || RESULT="no"
        if [[ $RESULT="no" ]] ; then
            f_info "Directory ~/.bosh does not exist - create new one..."
            mkdir -p ~/.bosh
            f_verify
        fi
        f_info "Certificate does not exist - moving one to ~/.bosh/root_ca_certificate..."
        mv /tmp/root_ca_certificate ~/.bosh/root_ca_certificate
    fi

    for i in 1 2 3 4
    do
        om -t https://10.173.61.130 -u admin -p VMware1! -k curl -p /api/v0/deployed/director/credentials/bosh_commandline_credentials -s | jq '.[]' | awk "{print $3}" | sed 's/"//g' | sed 's/\/var\/tempest\/workspaces\/default/~\/.bosh/g' >> /tmp/BOSH.env
    done

    source /tmp/BOSH.env

    bosh vms

#    PASSWD=$( om -t https://${OPSMAN_URL} -u "${OPSMAN_ADMIN}" -p "${OPSMAN_PASSWORD}" -k curl -p /api/v0/deployed/director/credentials/director_credentials -s | jq '.[] | .value.password' | sed -e "s/\"//g"  | sed -e "\/var\/tempest\/workspaces\/default/\~\/.bosh\/root_ca_cert//g'" )
#
#    echo -e "director\n${PASSWD}" | bosh -e pks log-in

}

f_init(){
    f_input_vars BITSDIR

    source /tmp/pks_variables

    if [ -f /tmp/.secret ] ; then
        source /tmp/.secret
    fi


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
        cp /tmp/pks_variables /tmp/pks_variables_old
        >/tmp/pks_variables
    fi

f_startup_question
f_choice_question

cat /tmp/pks_variables
rm -Rf /tmp/pks_variables

f_info "PKS Client setup COMPLETED - please check logs for details"

