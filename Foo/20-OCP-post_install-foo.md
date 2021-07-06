## Update Certs
I created a separate doc for the Cert section as it is not a *requirement*
review [LetsEncrypt-HowTo](./lets_encrypt.md)
NOTE:  This *should* be managed with CertManager (some time in the future).

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
TL;DR: make the following update
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

### Increase the worker node capacity, if necessary (or scale down to save capacity:
I scale my cluster back for workers to allow for more infra and OCS nodes
```
MACHINESET=$(oc get machineset -n openshift-machine-api | grep -v ^NAME | awk '{ print $1 }')
oc scale --replicas=2 machineset $MACHINESET  -n openshift-machine-api
```

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
cd ${OCP4DIR}
wget https://github.com/cloudxabide/matrix.lab/raw/main/images/LinuxRevolution_RedGradient.png -O ${OCP4DIR}/LinuxRevolution_RedGradient.png

oc create configmap console-custom-logo --from-file ${OCP4DIR}/LinuxRevolution_RedGradient.png  -n openshift-config
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
