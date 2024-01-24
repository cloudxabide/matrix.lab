## Update Certs
I created a separate doc for the Cert section as it is not a *requirement*
review [LetsEncrypt-HowTo](./25-OCP4-lets_encrypt.md)
NOTE:  This *should* be managed with CertManager (some time in the future).

##  Cleanup (existing/previous) Registry NFS
Since I am rebuilding the lab quite a bit, I need to remove the previously used registry  

Go to Seraph and run
```
ssh root@seraph.matrix.lab "rm -rf /mnt/ssd-1tb//nfs-registry/docker"
```

## Registry (NFS)
For *my* enviromment, NFS was the ideal target for the registry as it provides RWX as is ideal.  
NOTE: it is assumed that OCP has been successfully installed by this time.  

### Login to the system (if you're not already logged in)
```
USERNAME=kubeadmin
PASSWORD=$(cat $(find ${HOME}/OCP4/*mwn* -name kubeadmin-password | tail -1))
OCP4API=api.ocp4-mwn.linuxrevolution.com
OCP4APIPORT=6443
echo | openssl s_client -connect $OCP4API:$OCP4APIPORT -servername $OCP4API  | sed -n /BEGIN/,/END/p > $OCP4API.pem
oc login --certificate-authority=$OCP4API.pem --username=$USERNAME --password=$PASSWORD --server=$OCP4API:$OCP4APIPORT
```

### Create the yaml definition for the registry PV and PVC
#### NOTE: go remove seraph:/mnt/raidZ/nfs-registry/docker
```
[ -e $OCP4_DIR ] && OCP4_DIR=`dirname $(find $HOME/OCP4 -name terraform.*tfstate | tail -1)`
mkdir ${OCP4_DIR}/Registry; cd $_
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
    path: /mnt/ssd-1tb/nfs-registry
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
TL;DR: make the following update via the following commands: 
https://examples.openshift.pub/#kubectloc-patch
```
oc get configs.imageregistry.operator.openshift.io -o yaml > registry-0.yaml
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'
oc patch configs.imageregistry.operator.openshift.io cluster --type=merge --patch '{"spec":{"storage":{"pvc":{"claim":"image-registry-pvc"}}}}'
oc get configs.imageregistry.operator.openshift.io -o yaml > registry-1.yaml
sdiff registry-0.yaml registry-1.yaml | egrep '\||>|<'
```

Or, manually update using the changes (below) and close the file  
NOTE:  you are editing the lower section of the config once it's opened
```
oc edit configs.imageregistry.operator.openshift.io -o yaml
```
Set the following
```
managementState: Removed
managementState: Managed
```
and
```
  strorage: {}
to 
  storage:
    pvc:
      claim: image-registry-pvc
```

```
oc get clusteroperator image-registry
while true; do oc get clusteroperator image-registry; sleep 2; done
```

### Increase the worker node capacity, if necessary (or scale down to save capacity:
I scale my cluster back for workers to allow for more infra and OCS nodes
```
MACHINESET=$(oc get machineset -n openshift-machine-api | grep -v ^NAME | awk '{ print $1 }')
oc scale --replicas=2 machineset $MACHINESET  -n openshift-machine-api
```

```
MACHINESET=$(oc get machineset -n openshift-machine-api | grep -v ^NAME | awk '{ print $1 }')
oc edit machineset $MACHINESET -n openshift-machine-api

          memoryMiB: 8192
          numCPUs: 2
          numCoresPerSocket: 1

          memoryMiB: 12288
          numCPUs: 2
          numCoresPerSocket: 2
```

#### OC Patch method (testing - not yet working)
```
MACHINESET=$(oc get machineset -n openshift-machine-api | grep -v ^NAME | awk '{ print $1 }')
oc patch machineset.machine.openshift.io/$MACHINESET -n openshift-machine-api --type merge --patch '{"spec":{"template":{"spec":{"providerSpec":{"value":{"MemoryMiB":"12288"}}}}}}'

#oc patch console.operator.openshift.io cluster --type merge --patch '{"spec":{"customization":{"customLogoFile":{"key":"LinuxRevolution_RedGradient.png"}}}}'


```

Then scale-down and scale-up
```
SLEEPYTIME=180
for NODE in $(oc get nodes | awk '{ print $1 }' |  grep worker)
do 
  oc delete node $NODE; sleep $SLEEPYTIME; oc delete machine $NODE -n openshift-machine-api; sleep $SLEEPYTIME
done
```

## Customize the OpenShift Console logo

```
cd ${OCP4_DIR}
wget https://github.com/cloudxabide/matrix.lab/raw/main/images/LinuxRevolution_RedGradient.png -O ${OCP4_DIR}/LinuxRevolution_RedGradient.png

oc create configmap console-custom-logo --from-file ${OCP4_DIR}/LinuxRevolution_RedGradient.png  -n openshift-config
oc patch console.operator.openshift.io cluster --type merge --patch '{"spec":{"customization":{"customLogoFile":{"key":"LinuxRevolution_RedGradient.png"}}}}'
oc patch console.operator.openshift.io cluster --type merge --patch '{"spec":{"customization":{"customLogoFile":{"name":"console-custom-logo"}}}}'
oc patch console.operator.openshift.io cluster --type merge --patch '{"spec":{"customization":{"customProductName":"LinuxRevolution Console"}}}'

# OR...
oc edit console.operator.openshift.io cluster
# Update spec: customization: customLogoFile: {key,name}:
## add after "spec:operatorLogLevel: Normal"
  operatorLogLevel: Normal
  customization:
    customLogoFile:
      key: LinuxRevolution_RedGradient.png
      name: console-custom-logo
    customProductName: LinuxRevolution Console
```

## Enable "Simple Content Access (SCA)" for entitled builds
Status:  Work in Progress - I don't actually know how to fix this yet
https://docs.openshift.com/container-platform/4.10/cicd/builds/running-entitled-builds.html
https://docs.openshift.com/container-platform/4.10/support/remote_health_monitoring/insights-operator-simple-access.html
