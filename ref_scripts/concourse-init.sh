ROOT_WORK_DIR="/home/workspace"
BIND_MOUNT_DIR="/home/concourse"
CONFIG_FILE_NAME="nsx_pipeline_config.yml"
CONCOURSE_TARGET=pks-concourse
PIPELINE_NAME=install-pks-pipeline
echo "logging into concourse at $CONCOURSE_URL"
fly -t $CONCOURSE_TARGET sync
fly --target $CONCOURSE_TARGET login --insecure --concourse-url $CONCOURSE_URL -n main
pipeline_dir=${ROOT_WORK_DIR}/nsx-t-datacenter-ci-pipelines
pks_pipeline_dir=${ROOT_WORK_DIR}/nsx-t-ci-pipeline
concourse_docker_dir=${ROOT_WORK_DIR}/concourse-docker
fly -t $CONCOURSE_TARGET set-pipeline -p $PIPELINE_NAME -c ${pks_pipeline_dir}/pipelines/install-pks-pipeline.yml -l ${BIND_MOUNT_DIR}/${CONFIG_FILE_NAME}
