set -o pipefail

[ "${DEBUG,,}" == "true" ] && set -x

my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"

source "$my_dir/definitions"

if [[ ${IMAGE_TYPE^^} == 'RHCOS45' ]]; then
  echo "INFO: prepared image doesn't require special preparation - it was created with base image. Exiting"
  exit
fi

for i in "${!OS_IMAGE_USERS[@]}"; do
  if [[ ${IMAGE_TYPE^^} == 'ALL' && ${IMAGE_TYPE^^} == 'RHCOS45' ]]; then
    # skip preparation for RHCOS image
    continue
  fi
  if [[ ${IMAGE_TYPE^^} != 'ALL' && ${IMAGE_TYPE^^} != ${i^^} ]]; then
    continue
  fi

  echo "INFO: pack image for $i and upload it"
  packer build -machine-readable -var "os_image=${i,,}" -var "ssh_user=${OS_IMAGE_USERS[$i]}" \
      ${WORKSPACE}/src/tungstenfabric/tf-jenkins/infra/packer/vexxhost.json
  OLD_IMAGES=$(openstack image list --tag prepared-${i,,} -c Name -f value | sort -nr | tail -n +4)
  for o in $OLD_IMAGES; do
    echo "INFO: remove old image $o"
    openstack image delete $o
  done
done
