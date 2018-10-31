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

   5  ROOT_WORK_DIR="/home/workspace"
    6  BIND_MOUNT_DIR="/home/concourse"
    7  CONFIG_FILE_NAME="nsx_pipeline_config.yml"
    8  pipeline_internal_config="pipeline_config_internal.yml"
    9  concourse_version=3.14.1
   10  CONCOURSE_TARGET=nsx-concourse
   11  PIPELINE_NAME=nsx-t-install
   12  fly -t $CONCOURSE_TARGET sync
   13  fly --target $CONCOURSE_TARGET login --insecure --concourse-url $CONCOURSE_URL -n main
   14  ly_reset_cmd="fly -t $CONCOURSE_TARGET set-pipeline -p $PIPELINE_NAME -c ${pipeline_dir}/pipelines/nsx-t-install.yml -l ${BIND_MOUNT_DIR}/${pipeline_internal_config} -l ${BIND_MOUNT_DIR}/${CONFIG_FILE_NAME}"
   15  fly -t $CONCOURSE_TARGET set-pipeline -p $PIPELINE_NAME -c ${pipeline_dir}/pipelines/nsx-t-install.yml -l ${BIND_MOUNT_DIR}/${pipeline_internal_config} -l ${BIND_MOUNT_DIR}/${CONFIG_FILE_NAME}
   16  concourse_docker_dir=${ROOT_WORK_DIR}/concourse-docker
   17  pipeline_dir=${ROOT_WORK_DIR}/nsx-t-datacenter-ci-pipelines
   18  fly -t $CONCOURSE_TARGET set-pipeline -p $PIPELINE_NAME -c ${pipeline_dir}/pipelines/nsx-t-install.yml -l ${BIND_MOUNT_DIR}/${pipeline_internal_config} -l ${BIND_MOUNT_DIR}/${CONFIG_FILE_NAME}
   19  history
   20  fly -t $CONCOURSE_TARGET set-pipeline -p $PIPELINE_NAME -c ${pipeline_dir}/pipelines/nsx-t-install.yml -l ${BIND_MOUNT_DIR}/${pipeline_internal_config} -l ${BIND_MOUNT_DIR}/${CONFIG_FILE_NAME}
   21  history
