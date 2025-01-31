#!/bin/bash -eE
set -o pipefail

[ "${DEBUG,,}" == "true" ] && set -x

my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"

source "$my_dir/definitions"

# Note: Base images centos8 rhel7 rhel8 must be updated manually.
# The image name should follow the example: base-rhel8-202012321201.

date_suffix=$(date +%Y%m%d%H%M)

# Get images
if [[ ${IMAGE_TYPE^^} == 'ALL' || ${IMAGE_TYPE^^} == 'CENTOS7' ]]; then
  echo "INFO: download centos7 from centos.org"
  curl -LOs "https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2.xz"
  echo "INFO: decompress centos7"
  xz --decompress CentOS-7-x86_64-GenericCloud.qcow2.xz
  echo "INFO: upload centos7 to vexxhost"
  openstack image create --disk-format qcow2 --tag centos7 --file CentOS-7-x86_64-GenericCloud.qcow2 base-centos7-$date_suffix
  rm -f CentOS-7-x86_64-GenericCloud.qcow2*
fi

if [[ ${IMAGE_TYPE^^} == 'ALL' || ${IMAGE_TYPE^^} == 'UBUNTU18' ]]; then
  echo "INFO: download ubuntu18 from cloud-images"
  curl -LOs "https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
  curl -Ls "https://cloud-images.ubuntu.com/bionic/current/SHA256SUMS" -o ubuntu18-SHA256SUMS
  sha256sum -c ubuntu18-SHA256SUMS --ignore-missing --status
  echo "INFO: upload ubuntu18 to vexxhost"
  openstack image create --disk-format qcow2 --tag ubuntu18 --file bionic-server-cloudimg-amd64.img base-ubuntu18-$date_suffix
  rm -f bionic-server-cloudimg-amd64.img
fi

if [[ ${IMAGE_TYPE^^} == 'ALL' || ${IMAGE_TYPE^^} == 'RHCOS45' ]]; then
  echo "INFO: download RHCOS 4.5.6 from openshift mirror"
  curl -LOs "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.5/4.5.6/rhcos-4.5.6-x86_64-openstack.x86_64.qcow2.gz"
  curl -Ls "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.5/4.5.6/sha256sum.txt" -o rhcos45-SHA256SUMS
  sha256sum -c rhcos45-SHA256SUMS --ignore-missing --status
  echo "INFO: upload RHCOS45 to vexxhost"
  gzip -d rhcos-4.5.6-x86_64-openstack.x86_64.qcow2.gz
  openstack image create --disk-format qcow2 --tag rhcos45 --file rhcos-4.5.6-x86_64-openstack.x86_64.qcow2 base-rhcos45-$date_suffix
  openstack image create --disk-format qcow2 --tag prepared-rhcos45 --file rhcos-4.5.6-x86_64-openstack.x86_64.qcow2 prepared-rhcos45-$date_suffix
  rm -f rhcos-4.5.6-x86_64-openstack.x86_64.qcow2
fi

sleep 10
echo "INFO: uploaded image"
openstack image show base-${IMAGE_TYPE,,}-$date_suffix

# Remove previous images
# this code leaves 4 latest images - so it can be run always
echo "INFO: remove previous images"
IMAGES_LIST=$(openstack image list -c Name -f value | grep "^base-")
OS_NAMES=$(echo "$IMAGES_LIST" | awk -F "-" '{print $2}' | sort | uniq)

for o in $OS_NAMES; do
  OLD_IMAGES=$(echo "$IMAGES_LIST" | grep "$o" | sort -nr | tail -n +4)
  for i in $OLD_IMAGES; do
    echo "INFO: remove $i"
    openstack image delete $i
  done
done
