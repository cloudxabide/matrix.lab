# Red Hat Advanced Cluster Security (RHACS)

Essentially we are talking about Stackrox.


## ProTips

## Install Red Hat Advanced Cluster Security

### Install the Red Hat Advanced Cluster Security Operator

Get
  * channel
  * catalog source
  * catalog source namespace

#### Create a Project/Namespace
I use this template to create the Namespace to provide the node-selector annotation

```
cd $OCP4_DIR
mkdir RHACS; cd $_
wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/rhacs-project.yaml
oc create -f ./rhacs-project.yaml
```

Otherwise, you could just run
```
oc new-project rhacs-project --description="Red Hat Advanced Cluster Security" --display-name="Red Hat Advanced Cluster Security" 
```

#### Create a Subscription to the Operator
```
export OPERATOR_NAME=rhacs-operator
export NAMESPACE=rhacs-operator

# oc get packagemanifests $OPERATOR_NAME -operator -o jsonpath="{range .status.channels[*]}Channel: {.name} currentCSV: {.currentCSV}{'\n'}{end}"
export CHANNEL=rhacs-3.69
export STARTING_CSV=rhacs-operator.v3.69.1

export CATALOG_SOURCE=$(oc get packagemanifests $OPERATOR_NAME  -o jsonpath={.status.catalogSource})
export CATALOG_SOURCE_NAMESPACE=$(oc get packagemanifests $OPERATOR_NAME -o jsonpath={.status.catalogSourceNamespace})

echo -e " OPERATOR_NAME: $OPERATOR_NAME\n NAMESPACE: $NAMESPACE\n CHANNEL: $CHANNEL\n CATALOG_SOURCE: $CATALOG_SOURCE\n CATALOG_SOURCE_NAMESPACE: $CATALOG_SOURCE_NAMESPACE\n STARTING_CSV: $STARTING_CSV"

cat << EOF > $OPERATOR_NAME.yaml
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: '$OPERATOR_NAME'
  namespace: '$NAMESPACE'
spec:
  channel: '$CHANNEL'
  installPlanApproval: Automatic
  name: '$OPERATOR_NAME'
  source: '$CATALOG_SOURCE'
  sourceNamespace: '$CATALOG_SOURCE_NAMESPACE'
  startingCSV: '$STARTING_CSV'
EOF
cat $OPERATOR_NAME.yaml
oc apply -f $OPERATOR_NAME.yaml
```

#### Create a Central Project (stackrox)
```
oc new-project stackrox --description "Stackrox Central (RHACS)" 
```

(deploy central in to stackrox namespace)

#### Gather RHACS data and endpoints
Retrieve Central Password
```
oc patch namespace stackrox --type=merge -p \
    '{"spec":{"nodeSelector": {"node-role.kubernetes.io/infra": ""},"tolerations": [{"effect":"NoSchedule","key": "node-role.kubernetes.io/infra","value": "reserved"},{"effect":"NoExecute","key": "node-role.kubernetes.io/infra","value": "reserved"}]}}'

scheduler.alpha.kubernetes.io/defaultTolerations: '[{"operator": "Exists", "effect":
      "NoSchedule", "key": "node-role.kubernetes.io/infra"}, {"operator": "Exists",
      "effect": "NoExecute", "key": "node-role.kubernetes.io/infra"} ]'

 oc -n stackrox get secret central-htpasswd -o go-template='{{index .data "password" | base64decode}}'
```

Retrieve Endpoint
```
oc -n stackrox get route central -o jsonpath="{.status.ingress[0].host}"
```

## References
