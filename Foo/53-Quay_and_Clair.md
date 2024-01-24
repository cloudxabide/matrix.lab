# Quay and Clair Overview 

Status:  I would not follow this doc at this time.


Quay, as I have learned, is an interesting beast.  There are numerous ways to deploy it, and possible architectures to use.  
I am going to deploy Quay as an Operator in my existing OpenShift Container Platform 4 (4.10 at this time) Cluster which has OpenShift Data Foundations (supplying Object Store via Nooba) in my homelab.

## ProTips
* When you see "managed" or "unmanaged"
  * Manaaged:  this means the component is managed by the Operator
  * Unmanaged:  this means the component is not managed by the operator, but, instead, managed externally
* The docs are kind of all over the place - if you're confused/aggravated, it's not you.
* I provided several links below of what I could find to help bolster knowledge on Quay (I hope that more/better things are released soon)
* Many of the tutorials I found were focused on *using/configuring* Quay, and not installing it.  This is fine, I estimate that 1 out of 5 might actually be doing the install vs using it ;-)
* You WILL want object-storage for Quay if this is any sort of Production instance.
* Not all components need to be replicated, nor HA (will dive in to this later)

## Install Quay (as an Operator)

### Install the Quay Operator

Get
  * channel
  * catalog source
  * catalog source namespace

#### Create a Project/Namespace
I use this template to create the Namespace to provide the node-selector annotation

```
cd $OCP4_DIR
mkdir Quay; cd $_
wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/quay-project.yaml
oc create -f ./quay-project.yaml
```

Otherwise, you could just run
```
oc new-project quay-enterprise --description="Quay Enterprise" --display-name="Quay Enterprise Registry" 
```

#### Create a Subscription to the Operator
```
export OPERATOR_NAME=quay-operator
export NAMESPACE=openshift-operators

# oc get packagemanifests $OPERATOR_NAME -operator -o jsonpath="{range .status.channels[*]}Channel: {.name} currentCSV: {.currentCSV}{'\n'}{end}"
export CHANNEL=stable-3.6
export STARTING_CSV=quay-operator.v3.6.5

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

#### Create Config Bundle Secret
```
wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/quay-config-bundle-secret.yaml
oc create -f quay-config-bundle-secret.yaml
```

#### Create a registry
```
wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/quay-registry.yaml
oc create -f quay-registry.yaml
oc project quay-enterprise
oc get all
oc get pods -w
```

#### Create a Quay (admin) user
Browse to:  
https://matrixlab-registry-quay-quay-enterprise.apps.ocp4-mwn.linuxrevolution.com/

* User: quayadmin 
* Pass: NotAPassword

### Cleanup
Status: Work in Progress
```
oc delete QuayRegistry matrixlab-registry -n quay-enterprise
oc delete secret/quay-config-bundle-secret -n quay-enterprise
```




## References
https://access.redhat.com/documentation/en-us/red_hat_quay
https://docs.projectquay.io/deploy_quay_on_openshift_op_tng.html#_installing_the_quay_operator_from_operatorhub  
https://quay.io/
[Get Quay Pull Secret](https://access.redhat.com/solutions/3533201)

If you only watch one video (for installation), make it this one (though.. it's quite dated and things have changed)
[Quay Setup Operator](https://www.youtube.com/watch?v=TCDmyIt1Fns) - Andy Block @RedHat  

[Quay Tutorial - Using Quay](https://quay.io/tutorial/)
[Batteries-Included Quay Install on Red Hat OpenShift](https://www.youtube.com/watch?v=1_6jLGF5ByE) - Alec Merdler @RedHat  
[](https://www.youtube.com/watch?v=DdSVgSopdJM) - Chris Short / Daniel Messer @RedHat.  Install Quay on a VM (non-Prod)  
