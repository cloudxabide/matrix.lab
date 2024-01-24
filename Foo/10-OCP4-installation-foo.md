# OCP4 Installation (IPI - VMware/AWS)
STATUS:  Work in Progress.  Trying to make this less dependent on the host it's 
           running on and PULL everything needed for all the tasks.
         This works for me at this point, but I am definitely open to 
           suggestions for improvement.

NOTES:  

## Pre-reqs
NOTE:  you don't *always* need to do this part.  It is here (mostly) as a reference.

### Some housekeeping (host packages)
```
sudo yum -y install wget tar unzip bind-utils git
```

### VMware Certificates | Install the certs from VMware vCenter
You likely won't need to do this, it's just for reference.  I need to make a check to see whether
the certs have already been imported.
```
sudo su -
VC_HOSTNAME="vmw-vcenter6.matrix.lab"; SHORTDATE=`date +%F`

CERT_BUNDLE=${VC_HOSTNAME}-${SHORTDATE}.zip
[ ! -f $CERT_BUNDLE ] && {
curl -k https://${VC_HOSTNAME}/certs/download.zip -o ${CERT_BUNDLE};
unzip ${CERT_BUNDLE} -d /var/tmp/${VC_HOSTNAME};
cp  /var/tmp/${VC_HOSTNAME}/certs/lin/*.0 /etc/pki/ca-trust/source/anchors/;
update-ca-trust extract;
}
[ `whoami` == "root" ] && exit
```

## Getting Started | Typical OCP4 Install
You should start your TMUX and *then* set your ENV vars

```
#  ############  #  ############
##          START HERE 
#  ############  #  ############
### Start your TMUX Session
export SHORTDATE=`date +%F`
which tmux || sudo yum -y install tmux
tmux new -s OCP4-${SHORTDATE}|| tmux attach -t OCP4-${SHORTDATE}

## If you decide to install a specific version (or Architecture), then explore the following:
export ARCH=amd64 
# export ARCH=arm64
# export VERSION=stable-4.6
# export VERSION=latest-4.6
# export VERSION=4.6.26
#export VERSION=latest  # Note: "latest" might not be tested and may actually be a non-successful candidate version
export VERSION=stable

### Set ENVIRONMENT VARS
### NOTE:  Need to figure out the image search for ARM64 (2022-01-30)
case $ARCH in
  arm64)
    export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=quay.io/openshift-release-dev/ocp-release-nightly:4.9.0-0.nightly-arm64-2021-08-16-154214
  ;;
  *)
    export RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$VERSION/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
  ;;
esac
echo "RELEASE IMAGE (for $VERSION): $RELEASE_IMAGE $OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE"

#################
## Pick a Hypervisor
PLATFORM=baremetalUPI
PLATFORM=aws
PLATFORM=vsphere

case $PLATFORM in
  vsphere|baremetalUPI)
    BASE_DOMAIN=linuxrevolution.com
    export REGION=mwn
  ;;
  aws)
    BASE_DOMAIN=clouditoutloud.com
    export REGION="us-east-1"
    export AWS_DEFAULT_PROFILE="ciol-jradtke"
  ;;
esac

# Customize the following, if you want a cluster name not based on the region
export CLUSTER_NAME=ocp4-${REGION}
echo "CLUSTER_NAME=$CLUSTER_NAME"

### You have to reset the ENV var now that you're in the tmux session
export THEDATE=`date +%F-%H%M`
OCP4_BASE=${HOME}/OCP4/; mkdir ${OCP4_BASE}; cd $_
OCP4_DIR=${OCP4_BASE}${CLUSTER_NAME}.${BASE_DOMAIN}-${THEDATE}
INSTALL_DIR="${OCP4_BASE}/installer-${SHORTDATE}"

# Create all the Directories, if missing
[ ! -d ${OCP4_BASE} ] && { mkdir ${OCP4_BASE}; cd $_; } || { cd ${OCP4_BASE}; }
[ ! -d ${OCP4_DIR} ] && { mkdir ${OCP4_DIR}; cd $_; } || { cd ${OCP4_DIR}; }
[ ! -d ${INSTALL_DIR} ] && { mkdir ${INSTALL_DIR}; cd $_; } || { cd ${INSTALL_DIR}; }
cd $OCP4_BASE

# First, identify the files and make sure they are present
### SSH tweaks
SSH_KEY_FILE="${HOME}/.ssh/id_rsa-${BASE_DOMAIN}"
SSH_KEY_FILE_PUB="${HOME}/.ssh/id_rsa-${BASE_DOMAIN}.pub"
#[ ! -f $SSH_KEY_FILE_PUB ] && { ssh-keygen -trsa -b 2048 -N '' -f $SSH_KEY_FILE; }
[ ! -f $SSH_KEY_FILE_PUB ] && { ssh-keygen -tecdsa -b521 -E sha512 -N '' -f $SSH_KEY_FILE; }
SSH_KEY=$(cat $SSH_KEY_FILE_PUB)

PULL_SECRET_FILE=${OCP4_BASE}pull-secret.txt
[ ! -f $PULL_SECRET_FILE ] && { echo "ERROR: Pull Secret File Not Available. Hit CTRL-C within 10 seconds."; sleep 10; exit 9; }
PULL_SECRET=$(cat $PULL_SECRET_FILE)
export BASE_DOMAIN SSH_KEY PULL_SECRET CLUSTER_NAME AWS_DEFAULT_PROFILE
echo -e "Base Domain: $BASE_DOMAIN \nCluster Name: $CLUSTER_NAME \nAWS Default Profile:  $AWS_DEFAULT_PROFILE \nSSH Key: $SSH_KEY"
echo "Pull Secret is hydrated"

case $PLATFORM in 
  aws)
    aws configure list
  ;;
esac

# Since my GIT repo name does not reflect the domain I use...
# THIS IS SOME FUTURE PROOFING HERE - for if/when I have separate repos based on domain
case $BASE_DOMAIN in
  linuxrevolution.com|clouditoutloud.com)
    REPO_NAME=matrix.lab
  ;;
  *)
    REPO_NAME=${BASE_DOMAIN}
  ;;
esac

# Download the client and installer
cd $INSTALL_DIR
[ -e $VERSION ] && VERSION="stable"
case `uname` in
  Linux)
    for FILE in openshift-install-linux.tar.gz openshift-client-linux.tar.gz
    do
      [ ! -f ${FILE} ] && { wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${VERSION}/${FILE}; tar -xvzf ${FILE}; }
    done
  ;;
  Darwin)
    for FILE in openshift-install-mac.tar.gz openshift-client-mac.tar.gz 
    do
      [ ! -f ${FILE} ] && { curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${VERSION}/${FILE} -o ${FILE}; tar -xvzf ${FILE}; }
    done
  ;;
esac
```

## Deploy (create) the cluster
```
eval "$(ssh-agent -s)"
ssh-add ${HOME}/.ssh/id_rsa-${BASE_DOMAIN}
cd ${OCP4_BASE}

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

# Update the following values
#   baseDomain  << the domain you plan to use
#   compute.replicas << you *may* wish to add compute nodes?
#   "NotAPassword" << replace this
# vi install-config-${PLATFORM}-${CLUSTER_NAME}.${BASE_DOMAIN}.yaml 
# sed -i -e 's/NotAPassword/NewPassHere/g' install-config-${PLATFORM}-${CLUSTER_NAME}.${BASE_DOMAIN}.yaml 

# The following creates the "install-config" - you should then make a copy of it
# ${INSTALL_DIR}/openshift-install create install-config --dir=${OCP4_DIR}/ --log-level=info

# Using the previously created install config.... 
#   Create an install-config.yaml from the template using 
#   the ENV variables set earlier (SSHKEY and PULLSECRET)
rm -rf ${OCP4_DIR}; mkdir ${OCP4_DIR}
envsubst < $INSTALL_CONFIG > ${OCP4_DIR}/install-config.yaml
# vi ${OCP4_DIR}/install-config.yaml

#  Make sure DNS is working for the 2 (minimum) values
case $PLATFORM in 
  vsphere|baremetalUPI)
    echo -e "api.${CLUSTER_NAME}.${BASE_DOMAIN}: `dig +short api.${CLUSTER_NAME}.${BASE_DOMAIN}`"
    echo -e "test.apps.${CLUSTER_NAME}.${BASE_DOMAIN}: `dig +short test.apps.${CLUSTER_NAME}.${BASE_DOMAIN}`"
    case $PLATFORM in
      baremetalUPI)
        dig +short api-int.${CLUSTER_NAME}.${BASE_DOMAIN}
      ;;
    esac
  ;;
esac

# Create the IAM role request
#oc adm release extract quay.io/openshift-release-dev/ocp-release:4.y.z-x86_64 --credentials-requests --cloud=aws
# oc adm release extract quay.io/openshift-release-dev/ocp-release:4.10-latest-x86_64 --credentials-requests --cloud=aws

# Let's roll
MYLOG="${OCP4_DIR}/mylog.log"
echo "Start: `date`" >> $MYLOG
${INSTALL_DIR}/openshift-install create manifests --dir=${OCP4_DIR}/ 
# 
case $PLATFORM in 
  baremetalUPI)
    ${INSTALL_DIR}/openshift-install create ignition-configs --dir=${OCP4_DIR}/ 
    wget -O $OCP4_DIR/manifests/cluster-network-03-config.yml https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/cluster-network-03-config.yml
    wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/merge-bootstrap.ign 
    rsync -tugpolvv ${OCP4_DIR}/*ign root@10.10.10.10:/var/www/bootstrap/
    wget -O /tmp/bootstrap.ign http://10.10.10.10/bootstrap/bootstrap.ign
 
    cd $OCP4_DIR; for FILE in $(ls *.ign); do FILENAME=$(echo $FILE | sed 's/.ign/.64/g'); base64 -w0 $FILE > $FILENAME; done
    # Clone to VM - update: guestinfo.ignition.config.data / guestinfo.ignition.config.data.encoding base64
    # Power on Bootstrap, Master(s)
    ${INSTALL_DIR}/openshift-install wait-for bootstrap-complete --dir=${OCP4_DIR}/ --log-level=debug 
    jq -r .infraID ${OCP4_DIR}/metadata.json 
  ;;
esac
    
${INSTALL_DIR}/openshift-install create cluster --dir=${OCP4_DIR}/ --log-level=debug 
echo "End: `date`" >> $MYLOG
# or....
# ${INSTALL_DIR}/openshift-install create cluster --dir=${OCP4_DIR}/ --log-level=debug > ${OCP4_DIR}/installation.log 2>&1 

export KUBECONFIG=${OCP4_DIR}/auth/kubeconfig

# ${INSTALL_DIR}/openshift-install destroy cluster --dir=${OCP4_DIR}/ --log-level=debug 
```

## Build the Installer (If you need some custom install options... otherwise, use the standard installer) 
```
git clone https://github.com/openshift/installer.git ${INSTALLER_DIR}
cd ${INSTALLER_DIR}
TAGS=libvirt hack/build.sh
cd -
```

## References
