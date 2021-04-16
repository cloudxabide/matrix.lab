# OpenShift Container Storage

A *very* brief overview of how to deploy OCS, which is likely to change.


```
ROLE=storage
INFRASTRUCTURE_ID=$(oc get -o jsonpath='{.status.infrastructureName}{"\n"}' infrastructure cluster)
OCP4DIR=$(dirname $(find ${HOME} -name terraform.tfstate | tail -1))
export ROLE INFRASTRUCTURE_ID

cd ${HOME}/OCP4
rm machineset-storage.yaml
wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/machineset-storage.yaml 
envsubst < machineset-storage.yaml > $OCP4DIR/machineset-storage.yaml
cat $OCP4DIR/machineset-storage.yaml
oc create -f $OCP4DIR/machineset-storage.yaml
oc get machineset -n openshift-machine-api
oc describe machineset ocp4-mwn-przzs-storage -n openshift-machine-api
```

## Install OCS Operator
https://console-openshift-console.apps.ocp4-mwn.linuxrevolution.com/operatorhub/all-namespaces
