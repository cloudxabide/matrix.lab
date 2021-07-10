# OCP4 Installation (IPI - VMware/AWS)
STATUS:  Work in Progress.  Trying to make this less dependent on the host it's running on and PULL
           everything needed for all the tasks.
         This works for me at this point, but I am definitely open to suggestions for improvement.

NOTES:  I have been running this installation as root - but, that is not necessary (other than the certificate stuff)

## Pre-reqs
NOTE:  you don't *always* need to do this part.  It is here (mostly) as a reference.

# Some housekeeping
sudo yum -y install wget tar unzip bind-utils

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
#  ############
# 
## START HERE 
#  
#  ############
### Start your TMUX Session
SHORTDATE=`date +%F`
which tmux || sudo yum -y install tmux
tmux new -s OCP4-${SHORTDATE}|| tmux attach -t OCP4-${SHORTDATE}

### Set ENVIRONMENT VARS
## If you decide to install a specific version, then run the following
#export VERSION=latest-4.6
export VERSION=4.6.26
export VERSION=latest
export RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$VERSION/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
echo "RELEASE IMAGE (for $VERSION): $RELEASE_IMAGE"

# VMware - mwn 
CLUSTER_NAME=ocp4-mwn
BASE_DOMAIN=linuxrevolution.com
HYPERVISOR=vsphere

# The OpenShift Installer defaults to the "default" AWS profile
# unsure if this is configurable.  Leaving the configuration in 
# my config, as a placeholder (in case I figure it out)
# AWS - us-east-1
AWS_DEFAULT_PROFILE="ciol-jradtke"
REGION="us-east-1"
CLUSTER_NAME=ocp4-${REGION}
BASE_DOMAIN=clouditoutloud.com
HYPERVISOR=aws

# AWS - us-gov-west-1
AWS_DEFAULT_PROFILE="awsgc-ciol"
REGION=us-gov-west-1
CLUSTER_NAME=ocp4-${REGION}
BASE_DOMAIN=clouditoutloud.com
HYPERVISOR=aws

### You have to reset the ENV var now that you're in the tmux session
SHORTDATE=`date +%F`
THEDATE=`date +%F-%H%M`
OCP4_BASE=${HOME}/OCP4/; mkdir ${OCP4_BASE}; cd $_
OCP4DIR=${OCP4_BASE}${CLUSTER_NAME}.${BASE_DOMAIN}-${THEDATE}
INSTALL_DIR="${OCP4_BASE}/installer-${SHORTDATE}"

# Create all the Directories, if missing
[ ! -d ${OCP4_BASE} ] && { mkdir ${OCP4_BASE}; cd $_; } || { cd ${OCP4_BASE}; }
[ ! -d ${OCP4DIR} ] && { mkdir ${OCP4DIR}; cd $_; } || { cd ${OCP4DIR}; }
[ ! -d ${INSTALL_DIR} ] && { mkdir ${INSTALL_DIR}; cd $_; } || { cd ${INSTALL_DIR}; }
cd $OCP4_BASE

# First, identify the files and make sure they are present
### SSH tweaks
SSH_KEY_FILE="${HOME}/.ssh/id_rsa-${BASE_DOMAIN}"
SSH_KEY_FILE_PUB="${HOME}/.ssh/id_rsa-${BASE_DOMAIN}.pub"
[ ! -f $SSH_KEY_FILE_PUB ] && { ssh-keygen -trsa -b 2048 -N '' -f $SSH_KEY_FILE; }
SSH_KEY=$(cat $SSH_KEY_FILE_PUB)

PULL_SECRET_FILE=${OCP4_BASE}pull-secret.txt
[ ! -f $PULL_SECRET_FILE ] && { echo "ERROR: Pull Secret File Not Available"; exit 9; }
PULL_SECRET=$(cat $PULL_SECRET_FILE)
export BASE_DOMAIN BRIDGE_NAME SSH_KEY PULL_SECRET CLUSTER_NAME AWS_DEFAULT_PROFILE
echo $BASE_DOMAIN $BRIDGE_NAME $SSH_KEY $PULL_SECRET $CLUSTER_NAME $AWS_DEFAULT_PROFILE

case $HYPERVISOR in 
  aws)
    aws configure list
  ;;
esac


# Since my repo name does not reflect the domain I use...
# THIS IS SOME FUTURE PROOFING HERE - for if/when I have separate repos based on domain
case $BASE_DOMAIN in
  linuxrevolution.com)
    REPO_NAME=matrix.lab
  ;;
  *)
    REPO_NAME=${BASE_DOMAIN}
  ;;
esac

REPO_NAME=matrix.lab

# Download the client and installer
cd $INSTALL_DIR
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

## Build the Installer (If you need some custom install options... otherwise, use the standard installer)
```
git clone https://github.com/openshift/installer.git ${INSTALLER_DIR}
cd ${INSTALLER_DIR}
TAGS=libvirt hack/build.sh
cd -
```

## Deploy (create) the cluster
```
eval "$(ssh-agent -s)"
ssh-add ${HOME}/.ssh/id_rsa-${BASE_DOMAIN}
cd ${OCP4_BASE}
## Pull down a copy of the install-config with no personal data (you'll add your own personal data in a bit)
[ ! -f install-config-${HYPERVISOR}-${CLUSTER_NAME}.${BASE_DOMAIN}.yaml ] && { wget https://raw.githubusercontent.com/cloudxabide/${REPO_NAME}/main/Files/install-config-${HYPERVISOR}-${CLUSTER_NAME}.${BASE_DOMAIN}.yaml; echo "You need to update the config file found in this directory"; }

# Update the following values
#   platform.libvirt.network.if << This is the bridge that will be created
#   baseDomain  << the domain you plan to use
#   compute.replicas << you *may* wish to add compute nodes?
#   "NotAPassword" << replace this
cat install-config-${HYPERVISOR}-${CLUSTER_NAME}.${BASE_DOMAIN}.yaml 

# The following creates the "install-config" - you should then make a copy of it
#./openshift-install create install-config --dir=${OCP4DIR}/ --log-level=info

# Using the previously created install config.... Create an install-config.yaml from the template using 
# the ENV variables set earlier (SSHKEY and PULLSECRET)
envsubst < install-config-${HYPERVISOR}-${CLUSTER_NAME}.${BASE_DOMAIN}.yaml > ${OCP4DIR}/install-config.yaml
vi  ${OCP4DIR}/install-config.yaml

#  Make sure DNS is working for the 2 (minimum) values
case $HYPERVISOR in 
  vsphere)
nslookup api.${CLUSTER_NAME}.${BASE_DOMAIN}
nslookup test.apps.${CLUSTER_NAME}.${BASE_DOMAIN}
  ;;
esac

# Let's roll
${INSTALL_DIR}/openshift-install create cluster --dir=${OCP4DIR}/ --log-level=debug 
# or....
# ${INSTALL_DIR}/openshift-install create cluster --dir=${OCP4DIR}/ --log-level=debug > ${OCP4DIR}/installation.log 2>&1 

export KUBECONFIG=${OCP4DIR}/auth/kubeconfig
```

## Troubleshooting the Install
You can review the progress directly from the bootstrap system  

TL;DR:
```
ssh -i ~/.ssh/id_rsa-aperturelab core@192.168.126.10
  journalctl -b -f -u release-image.service -u bootkube.service
```


It appears that initially you will initially see:
* "Golden Image" (rhcos) node
* Masters
* Bootstrap

It is normal to see the API timeouts (around 5 times seems "normal"
```
time="2020-12-02T11:46:22-06:00" level=info msg="Waiting up to 20m0s for the Kubernetes API at https://api.ocp4-mwn.linuxrevolution.com:6443..."
time="2020-12-02T11:46:25-06:00" level=debug msg="Still waiting for the Kubernetes API: Get \"https://api.ocp4-mwn.linuxrevolution.com:6443/version?timeout=32s\": dial tcp 10.10.10.161:6443: connect: no route to host"
time="2020-12-02T11:47:10-06:00" level=debug msg="Still waiting for the Kubernetes API: Get \"https://api.ocp4-mwn.linuxrevolution.com:6443/version?timeout=32s\": dial tcp 10.10.10.161:6443: connect: no route to host"
time="2020-12-02T11:47:55-06:00" level=debug msg="Still waiting for the Kubernetes API: Get \"https://api.ocp4-mwn.linuxrevolution.com:6443/version?timeout=32s\": dial tcp 10.10.10.161:6443: connect: no route to host"
time="2020-12-02T11:48:18-06:00" level=debug msg="Still waiting for the Kubernetes API: Get \"https://api.ocp4-mwn.linuxrevolution.com:6443/version?timeout=32s\": dial tcp 10.10.10.161:6443: connect: connection refused"
time="2020-12-02T11:48:21-06:00" level=info msg="API v1.19.0+d59ce34 up"
```
Then, eventually you will see the worker nodes spinning up.

```
ssh core@(IP OF BOOTSTRAP)
journalctl -b -f -u bootkube.service
```
Also, I find the DHCPD logs to be helpful
Note you should see requests from nodes sending "clustername-clusterID-{master,worker}-randomID"
```
journalctl -f -u dhcpd
Dec 02 12:11:19 rh7-sat6-srv01.matrix.lab dhcpd[9566]: DHCPREQUEST for 10.10.10.199 from 00:50:56:a5:40:2e (ocp4-mwn-kkdz5-worker-rnphr) via ens192
```

## Login to the Environment

```
oc login -u kubeadmin -p `cat $(find $OCP4DIR/ -name kubeadmin-password)`  https://api.ocp4-mwn.linuxrevolution.com:6443/
# export KUBECONFIG=/root/OCP4/${OCP4DIR}/auth/kubeconfig
oc get nodes
```

### Create IAM Manifests
cd $INSTALL_DIR

./openshift-install create install-config --dir=${INSTALL_DIR}
./openshift-install create manifests --dir=${INSTALL_DIR}

## References
https://www.virtuallyghetto.com/2020/07/using-the-new-installation-method-for-deploying-openshift-4-5-on-vmware-cloud-on-aws.html
https://docs.openshift.com/container-platform/4.6/web_console/customizing-the-web-console.html

### Custom Machinesets during IPI install
https://github.com/openshift/installer/blob/master/docs/user/customization.md
https://github.com/openshift/installer/blob/master/docs/user/vsphere/customization.md#machine-pools

## Random foo
```
for IP in `oc get nodes -o wide | awk '{ print $6 }' | grep -v INT`; do ssh core@${IP} "grep proc /proc/cpuinfo"; done
for IP in `oc get nodes -o wide | awk '{ print $6 }' | grep -v INT`; do ssh core@${IP} "uptime"; done
```

```
oc get pods --all-namespaces | egrep -v 'Running' | awk '{ print "oc delete pod " $2 " -n " $1 }' > /tmp/blah
sh /tmp/blah
```
### Clean up between cluster deploys
```
ssh seraph.matrix.lab
rm -rf /mnt/raidZ/nfs-registry/docker
```

```
export KUBECONFIG=$(find ~/OCP4/*acm* -name kubeconfig)
cat $(find ~/OCP4/*acm* -name kubeadmin-password)
oc login -u kubeadmin -p `cat $(find ${HOME}/OCP4/*acm* -name kubeadmin-password)`  https://api.ocp4-acm.linuxrevolution.com:6443/

export KUBECONFIG=$(find ~/OCP4/*mwn* -name kubeconfig)
cat $(find ~/OCP4/*mwn* -name kubeadmin-password)
oc login -u kubeadmin -p `cat $(find ${HOME}/OCP4/*mwn* -name kubeadmin-password)`  https://api.ocp4-mwn.linuxrevolution.com:6443/


