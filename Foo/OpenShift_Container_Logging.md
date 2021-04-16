# OpenShift Container Logging

This will provide guidance on adding the EFK stack to OCP 4:

```
ROLE=efkstack
INFRASTRUCTURE_ID=$(oc get -o jsonpath='{.status.infrastructureName}{"\n"}' infrastructure cluster)
OCP4DIR=$(dirname $(find ${HOME} -name terraform.tfstate | tail -1))
export ROLE INFRASTRUCTURE_ID

cd ${HOME}/OCP4
rm machineset-efkstack.yaml
wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/machineset-efkstack.yaml 
envsubst < machineset-efkstack.yaml > $OCP4DIR/machineset-efkstack.yaml
cat $OCP4DIR/machineset-efkstack.yaml
oc create -f $OCP4DIR/machineset-efkstack.yaml
oc get machineset -n openshift-machine-api
oc describe machineset ocp4-mwn-przzs-efkstack -n openshift-machine-api
```

## Install OCS Operator
https://console-openshift-console.apps.ocp4-mwn.linuxrevolution.com/operatorhub/all-namespaces
