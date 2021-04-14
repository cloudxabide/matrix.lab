# OpenShift Container Storage


```
ROLE=storage
INFRASTRUCTURE_ID=$(oc get -o jsonpath='{.status.infrastructureName}{"\n"}' infrastructure cluster)
export ROLE INFRASTRUCTURE_ID

cd ${HOME}/OCP4
rm machineset-storage.yaml
wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/machineset-storage.yaml 
envsubst < machineset-storage.yaml > $OCP4DIR/machineset-storage.yaml
oc create -f $OCP4DIR/machineset-storage.yaml
oc get machineset -n openshift-machine-api
oc describe machineset ocp4-mwn-przzs-storage -n openshift-machine-api
```

## Install OCS Operator
https://console-openshift-console.apps.ocp4-mwn.linuxrevolution.com/operatorhub/all-namespaces
