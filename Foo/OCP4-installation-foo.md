# OCP4 Installation (VMware/IPI)

STATUS:  BROKEN :-(  I did some merge foo that really screwed up this file.
         Previously: Work in Progress.  Trying to make this less dependent on the host it's running on and PULL
           everything needed for all the tasks.

NOTES:   I have been running this installation as root - but, that is not necessary (other than the certificate stuff)

## Environment Details

  OCP4_BASE=${HOME}/OCP4
  INSTALLDIR=${OCP4_BASE}/

I am struggling with a "chicken-before-egg" scenario with setting things up, but also integrating tmux in to this  mess

### Download the Installer and Client
```
# TODO: instead of doing an rm, figure out how to rename it based on the version or something
FILES="openshift-install-linux.tar.gz openshift-client-linux.tar.gz"
for FILE in $FILES
do
  [ -f $FILE ] && mv $FILE $FILE-`date +%F`
done

case `uname` in
  Linux)
    wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-install-linux.tar.gz
    wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
  ;;
  Darwin)
    curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-install-mac.tar.gz -o openshift-install-mac.tar.gz
    curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-mac.tar.gz -o openshift-client-mac.tar.gz
  ;;
esac

for FILE in openshift-install-*.tar.gz openshift-client-*.tar.gz; do tar -xvzf $FILE; done
```

## Getting Started | Typical OCP4 Install
You should start your TMUX and *then* set your ENV vars

### Start your TMUX Session
```
INSTALLDATE=`date +%F`
which tmux || yum -y install tmux
cd ${HOME}/OCP4/
tmux new -s OCP4-${INSTALLDATE}|| tmux attach -t OCP4-${INSTALLDATE}
```

### Set ENVIRONMENT VARS
```
CLUSTER_NAME=ocp4-mwn
BASE_DOMAIN=linuxrevolution.com
HYPERVISOR=vsphere

SHORTDATE=`date +%F`
THEDATE=`date +%F-%H%M`
OCP4_BASE=${HOME}/OCP4/
OCP4DIR=${OCP4_BASE}/${CLUSTER_NAME}.${BASE_DOMAIN}-${THEDATE}
INSTALLER_DIR="installer-${SHORTDATE}"
SSH_KEY_FILE="${HOME}/.ssh/id_rsa-${BASE_DOMAIN}.pub"
SSH_KEY=$(cat $SSH_KEY_FILE)
PULL_SECRET_FILE=${OCP4_BASE}/pull-secret.txt
PULL_SECRET=$(cat $PULL_SECRET_FILE)
export BASE_DOMAIN BRIDGE_NAME SSH_KEY PULL_SECRET CLUSTER_NAME

VC_HOSTNAME="vmw-vcenter6.matrix.lab"
[ ! -d ${OCP4_BASE} ] && { mkdir ${OCP4_BASE}; cd $_; } || { cd ${OCP4_BASE}; }

case $BASE_DOMAIN in 
  linuxrevolution.com)
    REPO_NAME=matrix.lab
  ;;
  *)
    REPO_NAME=${BASE_DOMAIN}
  ;;
esac
```

### VMware Certificates | Install the certs from VMware vCenter
You likely won't need to do this, it's just for reference.
```
CERT_BUNDLE=${VC_HOSTNAME}-${SHORTDATE}.zip
[ ! -f $CERT_BUNDLE ] && { 
curl -k https://${VC_HOSTNAME}/certs/download.zip -o ${CERT_BUNDLE}; 
unzip ${CERT_BUNDLE} -d $OCP4DIR/; 
cp  $OCP4DIR/certs/lin/*.0 /etc/pki/ca-trust/source/anchors/; 
update-ca-trust extract; 
}
```

### SSH tweaks
I create a separate SSH key just for this lab stuff (${HOME}/.ssh/id_rsa-${BASE_DOMAIN}
```
[ ! -f ${HOME}/.ssh/id_rsa-$BASE_DOMAIN ] && { echo | ssh-keygen -trsa -b2048 -N '' -f ${HOME}/.ssh/id_rsa-$BASE_DOMAIN; SSH_KEY=$(cat $SSH_KEY_FILE); }
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
sed -i -e '/^192.168.126/d' ~/.ssh/known_hosts
cd ${OCP4_BASE}
[ ! -f install-config-${HYPERVISOR}-${CLUSTER_NAME}.${BASE_DOMAIN}.yaml ] && { wget https://raw.githubusercontent.com/cloudxabide/${REPO_NAME}/main/Files/install-config-${HYPERVISOR}-${CLUSTER_NAME}.${BASE_DOMAIN}.yaml; echo "You need to update the config file found in this directory"; }

# Update the following values
#   platform.libvirt.network.if << This is the bridge that will be created
#   baseDomain  << the domain you plan to use
#   compute.replicas << you *may* wish to add compute nodes?
vi install-config-libvirt-${CLUSTER_NAME}.${BASE_DOMAIN}.yaml

# The following creates the "install-config" - copy it out of the directory
#./openshift-install create install-config --dir=${OCP4DIR}/ --log-level=info
# Using the previously created install config....
[ ! -d ${OCP4DIR}/ ] && mkdir ${OCP4DIR}/
cat << EOF >
install-config-libvirt-${CLUSTER_NAME}.${BASE_DOMAIN}.yaml > $OCP4DIR/install-config.yaml
${INSTALLER_DIR}/bin/openshift-install create cluster --dir=${OCP4DIR}/ --log-level=debug
sudo virsh net-list
ssh -i ~/.ssh/id_rsa-aperturelab core@192.168.126.10
  journalctl -b -f -u release-image.service -u bootkube.service


export KUBECONFIG=${OCP4DIR}/auth/kubeconfig
```












If you'd like to create an install configuration, or already have an existing install configuration:
```
cp install-config-vsphere.yaml $OCP4DIR/install-config.yaml
```

## Troubleshooting the Install
This is a work in progress  

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

## OCP4 on RHV (RHHI-V)
Status:  Untested.  I do not have an environment to test this with yet.

Datastore: vmstore
Cluster Name: Default

```
curl -k -u admin@internal:NotAPassword https://rh7-rhv4-mgr01.matrix.lab/ovirt-engine/api
dig api.ocp4-mwn.matrix.lab
dig test.apps.ocp4-mwn.matrix.lab
dig *.apps.ocp4-mwn.matrix.lab | grep "^*"
curl -k 'https://rh7-rhv4-mgr01.matrix.lab/ovirt-engine/services/pki-resource?resource=ca-certificate&format=X509-PEM-CA' -o /tmp/ca.pem
chmod 0644 /tmp/ca.pem
cp -p /tmp/ca.pem /etc/pki/ca-trust/source/anchors/ca-rh7-rhv4-mgr01.pem
update-ca-trust
```

I have a bit of an intersting situation - my HomeLab has it's own DNS (matrix.lab) but the exposed IP uses (linuxrevolution.com).  Therefore, I build my cluster using matrix.lab
- Values I used

```
? SSH Public Key /root/.ssh/id_rsa.pub
? Platform ovirt
? oVirt cluster Default
? oVirt storage domain vmstore
? oVirt network guest
? Internal API virtual IP 10.10.10.161
? Internal DNS virtual IP 10.10.10.163
? Ingress virtual IP 10.10.10.162
? Base Domain matrix.lab
? Cluster Name ocp4-mwn
? Pull Secret [? for help]
```


## Login to the Environment

```
oc login -u kubeadmin -p `cat $(find $OCP4DIR/ -name kubeadmin-password)`  https://api.ocp4-mwn.linuxrevolution.com:6443/
# export KUBECONFIG=/root/OCP4/${OCP4DIR}/auth/kubeconfig
oc get nodes
```

## Registry (NFS)
For *my* enviromment, NFS was the ideal target for the registry as it provides RWX as is ideal.
NOTE: it is assumed that OCP has been successfully installed by this time.
Also - I had to do some nonsense to make my freeNAS work for this (and it's likely NOT ideal)


### Create the yaml definition for the registry PV and PVC
#### NOTE: go remove seraph:/mnt/raidZ/nfs-registry/docker
```
mkdir ${OCP4DIR}/Registry; cd $_
cat << EOF > image-registry-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: image-registry-pv
spec:
  accessModes:
    - ReadWriteMany
  capacity:
      storage: 100Gi
  nfs:
    path: /mnt/raidZ/nfs-registry
    server: 10.10.10.19
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs-registry
EOF

cat << EOF > image-registry-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: image-registry-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources: 
    requests:
      storage: 100Gi
  volumeMode: Filesystem
  storageClassName: nfs-registry
EOF
```

### Create and Validate the PV/PVC
```
kubectl apply -f image-registry-pv.yaml
kubectl -n openshift-image-registry apply -f image-registry-pvc.yaml
kubectl -n openshift-image-registry get pvc
```

### Update the ImageRegistry Operator Config 
TL;DR: update  
```
managementState: Removed
managementState: Managed
```

```
strorage: {}
storage:  
  pvc:  
    claim: image-registry-pvc
```

NOTE:  you are editing the lower section of the config once it's opened
```
oc edit configs.imageregistry.operator.openshift.io -o yaml
## Apply the changes (above) and close the file
oc get clusteroperator image-registry
while true; do oc get clusteroperator image-registry; sleep 2; done
```

### Increase the worker node capacity, if necessary:
```
oc edit machineset -n openshift-machine-api

          memoryMiB: 8192
          numCPUs: 2
          numCoresPerSocket: 1

          memoryMiB: 12288 
          numCPUs: 2
          numCoresPerSocket: 2
```
Then scale-down and scale-up
```
MACHINESET=$(oc get machineset -n openshift-machine-api | grep -v ^NAME | awk '{ print $1 }')
oc scale --replicas=6 machineset $MACHINESET  -n openshift-machine-api
oc scale --replicas=3 machineset $MACHINESET  -n openshift-machine-api
```

## Customize the OpenShift Console logo

```
wget https://github.com/cloudxabide/matrix.lab/raw/main/images/LinuxRevolution_RedGradient.png -O ${OCP4DIR}/LinuxRevolution_RedGradient.png

oc create configmap console-custom-logo --from-file ${OCP4DIR}/LinuxRevolution_RedGradient.png  -n openshift-config
oc edit console.operator.openshift.io cluster
# Update spec: customization: customLogoFile: {key,name}:
## add after "operatorLogLevel: Normal"
  operatorLogLevel: Normal
  customization:
    customLogoFile:
      key: LinuxRevolution_RedGradient.png
      name: console-custom-logo
    customProductName: LinuxRevolution Console
```

## Add htpasswd 
### Create an HTPASSWD file

```
PASSWORD=""
HTPASSWD_FILE=${OCP4DIR}/htpasswd

htpasswd -b -c $HTPASSWD_FILE morpheus $PASSWORD
htpasswd -b $HTPASSWD_FILE ocpguest $PASSWORD
htpasswd -b $HTPASSWD_FILE ocpadmin $PASSWORD

oc create secret generic htpass-secret --from-file=htpasswd=${HTPASSWD_FILE} -n openshift-config
cat << EOF > ${OCP4DIR}/HTPasswd-CR
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: my_htpasswd_provider 
    mappingMethod: claim 
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret 
EOF

oc apply -f ${OCP4DIR}/HTPasswd-CR
# You need to login to the cluster with 'ocpadmin' user
oc adm policy add-cluster-role-to-user cluster-admin ocpadmin
```

## Add Legit Certs
review [LetsEncrypt-HowTo](./lets_encrypt.md)  
NOTE:  This *should* be done with CertManager (some time in the future).

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


