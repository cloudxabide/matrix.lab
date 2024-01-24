# Build Infrastructure Nodes 

This will provide guidance on building the Infra Nodes (non-ODF) for:
* Logging
* Monitoring
* Metrics
* Registry
* Routers 

```
export ZONE=HomeLab  # Potential Future Use?
export PLATFORM=vsphere

export ROLE=infra
export TYPE=worker
export CLUSTER_NAME=ocp4-mwn
export DOMAIN_NAME=linuxrevolution.com
export INFRASTRUCTURE_ID=$(oc get -o jsonpath='{.status.infrastructureName}{"\n"}' infrastructure cluster)

OCP4_DIR=$(dirname $(find ${HOME} -name terraform.*tfstate | tail -1))
echo -e " Role: $ROLE\n InfrastructureId: $INFRASTRUCTURE_ID\n Hypervisor: $PLATFORM\n ClusterName: $CLUSTER_NAME\n DomainName: $DOMAIN_NAME"
MACHINESET_MANIFEST=machineset-$PLATFORM-$CLUSTER_NAME.$DOMAIN_NAME-$ROLE.yaml

# Create the machineset
cd $OCP4_DIR
rm $MACHINESET_MANIFEST
wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/$MACHINESET_MANIFEST -O ${MACHINESET_MANIFEST}.tmp
envsubst < $MACHINESET_MANIFEST.tmp > $OCP4_DIR/$MACHINESET_MANIFEST
cat $OCP4_DIR/$MACHINESET_MANIFEST

# Create Machines and Watch
oc create -f $OCP4_DIR/$MACHINESET_MANIFEST
oc get machines -n openshift-machine-api -w

# Review (unnecessary step)
oc get machineset -n openshift-machine-api 
oc describe machineset $INFRASTRUCTURE_ID-$ROLE -n openshift-machine-api
oc get machines -n openshift-machine-api
```

```
# The Nodes *should* already be labeled
for NODE in $(oc get nodes | grep infra | grep -v odf | awk '{ print $1 }'); do oc label nodes $NODE node-role.kubernetes.io/infra=''; done
# Taint Infra nodes (as Unscheduable)
for NODE in $(oc get nodes | grep infra | grep -v odf | awk '{ print $1 }'); do oc adm taint nodes $NODE node-role.kubernetes.io/infra:NoSchedule; done
# To untaint the nodes
for NODE in $(oc get nodes | grep infra | grep -v odf | awk '{ print $1 }'); do oc adm taint nodes $NODE node-role.kubernetes.io/infra:NoSchedule-; done
```

### Label non-infra/ODF worker nodes with additional label of "app", then set default node-role to : app
```
# Make sure the right nodes will be identified
for NODE in $(oc get nodes | grep worker | egrep -v 'infra|odf' | awk '{ print $1 }'); do echo "$NODE"; done
# Label the nodes
for NODE in $(oc get nodes | grep worker | egrep -v 'infra|odf' | awk '{ print $1 }'); do oc label nodes $NODE node-role.kubernetes.io/app=''; done
oc get nodes -o wide
oc get nodes --show-labels
oc patch scheduler cluster --type=merge -p '{"spec":{"defaultNodeSelector":"node-role.kubernetes.io/app="}}'
```

## Add tolerations to daemonsets (this seems like it should be unnecessary)

### Move the "infra services" to the infra nodes
#### Move the router
```
oc patch ingresscontroller/default -n  openshift-ingress-operator  --type=merge -p '{"spec":{"nodePlacement": {"nodeSelector": {"matchLabels": {"node-role.kubernetes.io/infra": ""}},"tolerations": [{"effect":"NoSchedule","key": "node-role.kubernetes.io/infra","value": "reserved"},{"effect":"NoExecute","key": "node-role.kubernetes.io/infra","value": "reserved"}]}}}'
# Change to replicas: 3 (if desired)
oc patch ingresscontroller/default -n openshift-ingress-operator --type=merge -p '{"spec":{"replicas": 3}}'
oc get pods -nopenshift-ingress  -o wide 
```
#### Registry
```
oc get pods -n openshift-image-registry 
oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge -p '{"spec":{"nodeSelector": {"node-role.kubernetes.io/infra": ""},"tolerations": [{"effect":"NoSchedule","key": "node-role.kubernetes.io/infra","value": "reserved"},{"effect":"NoExecute","key": "node-role.kubernetes.io/infra","value": "reserved"}]}}'
oc get pods -n openshift-image-registry -o wide -w | egrep -v 'node'
```

#### Monitoring
See the OpenShift Logging and Monitoring Doc

#### Daemonsets
*IF* you encounter "broken" daemonsets, then...
```
oc edit dns.operator/default

spec:
  logLevel: Normal
  nodePlacement:
    tolerations:
    - operator: Exists
```

## Update remaining nodes
So, if you go about this, you *likely* want to (now) relabel your remaining "worker nodes" and then change the defaults
* Update the labels to nodes
* make unschedulable, when needed
* Change the default "project node-selector" based on role (to "app", or something?)
* Update existing projects "node-selector: "
* 

## References
https://access.redhat.com/solutions/5034771
