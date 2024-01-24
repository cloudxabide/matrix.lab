# OpenShift Logging

This will provide guidance on adding the EFK stack to OCP 4:

Assumption/Prereq:

* Infra Nodes have already been deployed [infra nodes](41-build_infra_nodes.md)
* OpenShift Data Foundation Nodes have already been deployed [OpenShift Data Foundations](40-OpenShift_Data_Foundations.md)

## Install/Configure Monitoring

Since you have deployed "infra nodes", use the following to make sure the components can run on the infra nodes

Create a configMap
```
cd $OCP4_DIR
(oc -n openshift-monitoring get configmap cluster-monitoring-config) || {
wget -O cluster-monitoring-configmap.yaml https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/cluster-monitoring-configmap.yaml
oc create -f cluster-monitoring-configmap.yaml
oc get configmap cluster-monitoring-configmap -n openshift-monitoring
}
```

## Install Logging
There are 2 methods, I am going to focus on the CLI method (in hopes it can be automated)

NOTE:  you can opt for another "channel" in the sub, i.e. stable-5.1
### CLI  
```
NAMESPACE=eo-namespace
NAMESPACE_DEFINITION=$NAMESPACE.yaml
cd $OCP4_DIR
cat << EOF > $NAMESPACE_DEFINITION
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-operators-redhat 
  annotations:
    openshift.io/node-selector: 'node-role.kubernetes.io/infra='
  labels:
    openshift.io/cluster-monitoring: "true"
EOF
oc create -f $NAMESPACE_DEFINITION
oc describe namespace $(grep name: $NAMESPACE_DEFINITION | awk -F\: '{ print $2 }') 

NAMESPACE=olo-namespace
NAMESPACE_DEFINITION=$NAMESPACE.yaml
cat << EOF > $NAMESPACE_DEFINITION
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-logging
  annotations:
    openshift.io/node-selector: 'node-role.kubernetes.io/infra='
    scheduler.alpha.kubernetes.io/defaultTolerations: >-
      [{"operator": "Exists", "effect": "NoSchedule", "key":
      "node-role.kubernetes.io/infra"},
        {"operator": "Exists", "effect": "NoExecute", "key":
      "node-role.kubernetes.io/infra"}
      ]
  labels:
    openshift.io/cluster-monitoring: "true"
EOF
oc create -f $NAMESPACE_DEFINITION
oc describe namespace $(grep name: $NAMESPACE_DEFINITION | awk -F\: '{ print $2 }') 
```

```
OPERATOR_GROUP=eo-og
OPERATOR_GROUP_DEFINTION=$OPERATOR_GROUP.yaml
cat << EOF >  $OPERATOR_GROUP_DEFINTION
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-operators-redhat
  namespace: openshift-operators-redhat 
spec: {}
EOF
oc create -f $OPERATOR_GROUP_DEFINTION
oc describe og $(grep name: $OPERATOR_GROUP_DEFINTION | awk -F\: '{ print $2 }') -n $(grep namespace: $OPERATOR_GROUP_DEFINTION | awk -F\: '{ print $2 }')

OPERATOR_GROUP=olo-og
OPERATOR_GROUP_DEFINTION=$OPERATOR_GROUP.yaml
cat << EOF > $OPERATOR_GROUP_DEFINTION
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cluster-logging
  namespace: openshift-logging 
spec:
  targetNamespaces:
  - openshift-logging 
EOF
oc create -f $OPERATOR_GROUP_DEFINTION
oc describe og $(grep name: $OPERATOR_GROUP_DEFINTION | awk -F\: '{ print $2 }') -n $(grep namespace: $OPERATOR_GROUP_DEFINTION | awk -F\: '{ print $2 }')
sleep 300
oc get csv -n openshift-logging -w

OPERATOR_SUB=olo-sub
OPERATOR_SUB_DEFINTION=$OPERATOR_SUB.yaml
cat << EOF > $OPERATOR_SUB_DEFINTION
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cluster-logging
  namespace: openshift-logging 
spec:
  channel: "stable" 
  name: cluster-logging
  source: redhat-operators 
  sourceNamespace: openshift-marketplace
EOF
oc create -f $OPERATOR_SUB_DEFINTION
oc describe sub $(grep name: $OPERATOR_SUB_DEFINTION | awk -F\: '{ print $2 }') -n $(grep namespace: $OPERATOR_SUB_DEFINTION | awk -F\: '{ print $2 }')
oc get csv -n openshift-logging

OPERATOR=olo-instance
OPERATOR_DEFINTION=$OPERATOR.yaml
cat << EOF > $OPERATOR_DEFINTION
apiVersion: "logging.openshift.io/v1"
kind: "ClusterLogging"
metadata:
  name: "instance" 
  namespace: "openshift-logging"
spec:
  managementState: "Managed"  
  logStore:
    type: "elasticsearch"  
    retentionPolicy: 
      application:
        maxAge: 1d
      infra:
        maxAge: 7d
      audit:
        maxAge: 7d
    elasticsearch:
      nodeCount: 3 
      storage:
        storageClassName: "ocs-storagecluster-ceph-rbd"
        size: 200G
      resources: 
        limits:
          memory: "16Gi"
        requests:
          memory: "16Gi"
      proxy: 
        resources:
          limits:
            memory: 256Mi
          requests:
             memory: 256Mi
      redundancyPolicy: "SingleRedundancy"
  visualization:
    type: "kibana"  
    kibana:
      replicas: 1
  collection:
    logs:
      type: "fluentd"  
      fluentd: {}
EOF
oc create -f $OPERATOR_DEFINTION
oc get pods -n openshift-logging -w

SUBSCRIPTION_OBJECT=eo-sub
SUBSCRIPTION_OBJECT_DEFINITION=$SUBSCRIPTION_OBJECT.yaml
cat << EOF > $SUBSCRIPTION_OBJECT_DEFINITION
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: "elasticsearch-operator"
  namespace: "openshift-operators-redhat"
spec:
  channel: "stable"
  installPlanApproval: "Automatic"
  source: "redhat-operators"
  sourceNamespace: "openshift-marketplace"
  name: "elasticsearch-operator"
EOF
oc create -f $SUBSCRIPTION_OBJECT_DEFINITION
oc describe sub $(grep name: $SUBSCRIPTION_OBJECT_DEFINITION | tail -1 | sed 's/\"//g'  awk -F\: '{ print $2 }') -n $(grep namespace: $SUBSCRIPTION_OBJECT_DEFINITION | tail -1 | sed 's/\"//g' |  awk -F\: '{ print $2 }')
oc get csv --all-namespaces | egrep -i elast

```


https://access.redhat.com/solutions/6719831
```
cat << EOF >  clusterlogging-collector-metrics.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: clusterlogging-collector-metrics
rules:
- apiGroups: [""]
  resources:
  - pods
  - services
  - endpoints
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
EOF 
oc create -f clusterlogging-collector-metrics.yaml

cat << EOF > clusterlogging-collector-metrics-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: clusterlogging-collector-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: clusterlogging-collector-metrics
subjects:
- kind: ServiceAccount
  name: prometheus-k8s
  namespace: openshift-monitoring 
EOF
oc create -f clusterlogging-collector-metrics-binding.yaml

```

## References
https://cloud.redhat.com/blog/configure-openshift-metrics-with-prometheus-backed-by-openshift-container-storage  
https://docs.openshift.com/container-platform/4.10/monitoring/configuring-the-monitoring-stack.html   
https://docs.openshift.com/container-platform/4.10/logging/cluster-logging-deploying.html  
https://docs.openshift.com/container-platform/4.10/logging/cluster-logging-deploying.html#cluster-logging-deploy-cli_cluster-logging-deploying
