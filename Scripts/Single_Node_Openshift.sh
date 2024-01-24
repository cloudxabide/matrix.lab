#!/bin/sh
#  Single Node Openshift (SNO)


# from Section 12.2.2 
#  https://docs.openshift.com/container-platform/4.10/installing/installing_sno/install-sno-preparing-to-install-sno.html

# I prefer to run scripts in a tmux session
do_tmux() {
export SHORTDATE=`date +%F`
which tmux || sudo yum -y install tmux
tmux new -s OCP4-${SHORTDATE}|| tmux attach -t OCP4-${SHORTDATE}
}

export ARCH=amd64
export VERSION=stable # example values: latest-4.10 4.6.26
export PLATFORM=none

export CLUSTER_NAME=ocp4-sno
export BASE_DOMAIN=matrix.lab

case $BASE_DOMAIN in
  linuxrevolution.com|clouditoutloud.com)
    REPO_NAME=matrix.lab
  ;;
  *)
    REPO_NAME=${BASE_DOMAIN}
  ;;
esac

export THEDATE=`date +%F-%H%M`
OCP4_BASE=${HOME}/OCP4/; mkdir ${OCP4_BASE}; cd $_
OCP4_DIR=${OCP4_BASE}${CLUSTER_NAME}.${BASE_DOMAIN}-${THEDATE}
INSTALL_DIR="${OCP4_BASE}installer-${SHORTDATE}"
echo -e "Parameters:\n DATE: $THEDATE\n OCP4_BASE: $OCP4_BASE\n OCP4_DIR: $OCP4_DIR\n INSTALL_DIR:  $INSTALL_DIR"

SSH_KEY_FILE="${HOME}/.ssh/id_rsa-${BASE_DOMAIN}"
SSH_KEY_FILE_PUB="${HOME}/.ssh/id_rsa-${BASE_DOMAIN}.pub"
[ ! -f $SSH_KEY_FILE_PUB ] && { ssh-keygen -tecdsa -b521 -E sha512 -N '' -f $SSH_KEY_FILE; }
SSH_KEY=$(cat $SSH_KEY_FILE_PUB)

PULL_SECRET_FILE=${OCP4_BASE}pull-secret.txt
[ ! -f $PULL_SECRET_FILE ] && { echo "ERROR: Pull Secret File Not Available"; sleep 5; exit 9; }
PULL_SECRET=$(cat $PULL_SECRET_FILE)
echo "Pull Secret is hydrated"
export BASE_DOMAIN SSH_KEY PULL_SECRET CLUSTER_NAME 
echo -e "Parameters:\n BASE_DOMAIN: $BASE_DOMAIN\n CLUSTER_NAME: $CLUSTER_NAME"

cd $INSTALL_DIR || { mkdir -p $INSTALL_DIR; cd $INSTALL_DIR; }
[ -e $VERSION ] && VERSION="stable"
for FILE in openshift-install-linux.tar.gz openshift-client-linux.tar.gz
do
  [ ! -f ${FILE} ] && { wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${VERSION}/${FILE}; tar -xvzf ${FILE}; }
done

chmod +x openshift-install

for HOST in api api-int *.apps
do 
  echo "$HOST.$CLUSTER_NAME.$BASE_DOMAIN: `dig +short $HOST.$CLUSTER_NAME.$BASE_DOMAIN`"
done

mkdir -p $OCP4_DIR; cd $_
ISO_URL=$($INSTALL_DIR/openshift-install coreos print-stream-json | grep location | grep x86_64 | grep iso | cut -d\" -f4)
echo -e "URL for ISO: $ISO_URL"
[ ! -f $OCP4_DIR/rhcos-live.x86_64.iso ] && { curl -o $OCP4_DIR/rhcos-live.x86_64.iso -L $ISO_URL; }
file $OCP4_DIR/rhcos-live.x86_64.iso

## Pull down a copy of the install-config with no personal data (you'll
#   add your own personal data in a bit)
case $ARCH in
  arm64)
    INSTALL_CONFIG=install-config-${PLATFORM}-${CLUSTER_NAME}.${BASE_DOMAIN}-arm64.yaml
  ;;
  *)
    INSTALL_CONFIG=install-config-${PLATFORM}-${CLUSTER_NAME}.${BASE_DOMAIN}.yaml
  ;;
esac
echo "Installation Configuration: $INSTALL_CONFIG"
[ ! -f $INSTALL_CONFIG ] && { wget https://raw.githubusercontent.com/cloudxabide/${REPO_NAME}/main/Files/$INSTALL_CONFIG; echo "You need to update the config file found in this directory"; }

envsubst < $INSTALL_CONFIG > ${OCP4_DIR}/install-config.yaml
vi ${OCP4_DIR}/install-config.yaml

$INSTALL_DIR/openshift-install --dir=$OCP4_DIR create single-node-ignition-config

cd $OCP4_DIR
alias coreos-installer='podman run --privileged --pull always --rm \ 
  -v /dev:/dev -v /run/udev:/run/udev -v $PWD:/data \
  -w /data quay.io/coreos/coreos-installer:release'
cp bootstrap-in-place-for-live-iso.ign iso.ign
coreos-installer iso ignition embed -fi iso.ign rhcos-live.x86_64.iso
# If you are on the same machine that you are creating your USB from
sudo dd if=./rhcos-live.x86_64.iso of=/dev/sda status=progress

cd $OCP4_DIR
oc login --insecure-skip-tls-verify=true -u kubeadmin -p `cat auth/kubeadmin-password ` https://api.${CLUSTER_NAME}.${BASE_DOMAIN}:6443 --loglevel 5

exit 0

## References
https://console.redhat.com/openshift/assisted-installer/clusters  
https://docs.openshift.com/container-platform/4.10/installing/installing_sno/install-sno-installing-sno.html
