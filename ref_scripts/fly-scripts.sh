#!/usr/bin/env bash
ROOT_WORK_DIR="/home/workspace"
BIND_MOUNT_DIR="/home/concourse"
CONFIG_FILE_NAME="nsx_pipeline_config.yml"

pipeline_internal_config="pipeline_config_internal.yml"
concourse_version=3.14.1
CONCOURSE_TARGET=nsx-concourse
PIPELINE_NAME=nsx-t-install
echo "logging into concourse at $CONCOURSE_URL"
fly -t $CONCOURSE_TARGET sync
fly --target $CONCOURSE_TARGET login --insecure --concourse-url $CONCOURSE_URL -n main
echo "setting the NSX-t install pipeline $PIPELINE_NAME"
fly_reset_cmd="fly -t $CONCOURSE_TARGET set-pipeline -p $PIPELINE_NAME -c ${pipeline_dir}/pipelines/nsx-t-install.yml -l ${BIND_MOUNT_DIR}/${pipeline_internal_config} -l ${BIND_MOUNT_DIR}/${CONFIG_FILE_NAME}"
yes | $fly_reset_cmd
echo "unpausing the pipeline $PIPELINE_NAME"
fly -t $CONCOURSE_TARGET unpause-pipeline -p $PIPELINE_NAME

# add an alias for set-pipeline command
echo "alias fly-reset=\"$fly_reset_cmd\"" >> ~/.bashrc
destroy_cmd="cd $BIND_MOUNT_DIR; fly -t $CONCOURSE_TARGET destroy-pipeline -p $PIPELINE_NAME; docker-compose down; docker stop nginx-server; docker rm nginx-server;"
echo "alias destroy=\"$destroy_cmd\"" >> ~/.bashrc
source ~/.bashrc

while true; do
	is_worker_running=$(docker ps | grep concourse-worker)
	if [[ ! $is_worker_running ]]; then
		docker-compose restart concourse-worker
		echo "concourse worker is down; restarted it"
		break
	fi
	sleep 5
done

sleep 3d
fly -t $CONCOURSE_TARGET destroy-pipeline -p $PIPELINE_NAME
docker-compose down
docker stop nginx-server
docker rm nginx-server
exit 0

ROOT_WORK_DIR="/home/workspace"
BIND_MOUNT_DIR="/home/concourse"
CONFIG_FILE_NAME="nsx_pipeline_config.yml"
pipeline_internal_config="pipeline_config_internal.yml"
concourse_version=3.14.1
CONCOURSE_TARGET=nsx-concourse
PIPELINE_NAME=nsx-t-install
fly -t $CONCOURSE_TARGET sync
fly --target $CONCOURSE_TARGET login --insecure --concourse-url $CONCOURSE_URL -n main
concourse_docker_dir=${ROOT_WORK_DIR}/concourse-docker
pipeline_dir=${ROOT_WORK_DIR}/nsx-t-datacenter-ci-pipelines
fly -t $CONCOURSE_TARGET set-pipeline -p $PIPELINE_NAME -c ${pipeline_dir}/pipelines/nsx-t-install.yml -l ${BIND_MOUNT_DIR}/${pipeline_internal_config} -l ${BIND_MOUNT_DIR}/${CONFIG_FILE_NAME}


   1  ls /home/concourse/
    2  clear
    3  ls -lrt /home/concourse/
    4  cd /home/concourse/
    5  ls
    6  ./run_pks.sh
    7  cat run_pks.sh
    8  ./run_pks.sh > log
    9  vi run_pks.sh
   10  cd /home/workspace/
   11  ls
   12  ls -lrt
   13  cd /home/concourse/
   14  ls
   15  ./run_pks.sh
   16  cd /home/concourse/
   17  ./run_pks.sh
   18  fly target
   19  fly
   20  fly env
   21  fly hijack
   22  fly hijack -t nsx-cocnourse
   23  fly hijack -t nsx-concourse
   24  fly targets
   25  fly hijack -t nsx-concourse -j configure-director/configure-director
   26  fly hijack -t nsx-concourse -j pks-install/configure-director
   27  pwd
   28  ll /tmp
   29  fly hijack -t nsx-concourse -j pks-install/configure-director
   30  $?
   31  fly hijack -t nsx-concourse -j pks-install/configure-director
   32  ROOT_WORK_DIR="/home/workspace"
   33  BIND_MOUNT_DIR="/home/concourse"
   34  CONFIG_FILE_NAME="nsx_pipeline_config.yml"
   35  pipeline_internal_config="pipeline_config_internal.yml"
   36  concourse_version=3.14.1
   37  CONCOURSE_TARGET=nsx-concourse
   38  PIPELINE_NAME=nsx-t-install
   39  fly -t $CONCOURSE_TARGET sync
   40  fly --target $CONCOURSE_TARGET login --insecure --concourse-url $CONCOURSE_URL -n main
   41  concourse_docker_dir=${ROOT_WORK_DIR}/concourse-docker
   42  pipeline_dir=${ROOT_WORK_DIR}/nsx-t-datacenter-ci-pipelines
   43  fly -t $CONCOURSE_TARGET set-pipeline -p $PIPELINE_NAME -c ${pipeline_dir}/pipelines/nsx-t-install.yml -l ${BIND_MOUNT_DIR}/${pipeline_internal_config} -l ${BIND_MOUNT_DIR}/${CONFIG_FILE_NAME}
   44  history


export BOSH_CLIENT=ops_manager
export BOSH_CLIENT_SECRET=ILkwwW14fGf5SOA1LpxL1AQl20D7-Aq3
export BOSH_CA_CERT=/var/tempest/workspaces/default/root_ca_certificate
export BOSH_ENVIRONMENT=172.16.0.89 bosh


docker run --name nsx-t-install -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/concourse:/home/concourse \
  -e CONCOURSE_URL="http://10.173.61.30:8080" \
  -e EXTERNAL_DNS="10.20.20.1" \
  -e IMAGE_WEBSERVER_PORT=40001 \
  -e VMWARE_USER='DL_admin@vmware.com' \
  -e VMWARE_PASSWORD='FT6MFRwzgK832!QU' \
  -e NSXT_VERSION='2.3'
  nsx-t-install