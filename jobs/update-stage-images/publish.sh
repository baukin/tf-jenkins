#!/bin/bash -eE
set -o pipefail

[ "${DEBUG,,}" == "true" ] && set -x

my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"

source "$my_dir/definitions"

if [ -z ${REPOS_TYPE} ]; then
  echo "ERROR: REPOS_TYPE is undefined or empty"
  exit 1
fi

rsync -a -e "ssh -i $WORKER_SSH_KEY $SSH_OPTIONS" {$WORKSPACE/src,$my_dir/*} $IMAGE_SSH_USER@$instance_ip:./

export CONTAINER_REGISTRY=${CONTAINER_REGISTRY:-"tf-mirrors.tfci.progmaticlab.com:5005"}

echo "INFO: update images started"
cat <<EOF | ssh -i $WORKER_SSH_KEY $SSH_OPTIONS $IMAGE_SSH_USER@$instance_ip
#!/bin/bash -e

[ "${DEBUG,,}" == "true" ] && set -x
export WORKSPACE=\$HOME
export DEBUG=$DEBUG
export REPOS_TYPE=$REPOS_TYPE
export PATH=\$PATH:/usr/sbin

export CONTAINER_REGISTRY=$CONTAINER_REGISTRY
./src/tungstenfabric/tf-dev-env/common/setup_docker.sh

echo "INFO: cat /etc/docker/daemon.json"
cat /etc/docker/daemon.json

./publish_docker_images.sh
EOF
echo "INFO: Publishing docker images is finished for $REPOS_TYPE"
