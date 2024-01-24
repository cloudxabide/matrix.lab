# Security And Compliance

## Compliance Operator

```
cd $OCP4_DIR
PKG=ComplianceOperator

cat << EOF > $PKG-namespace.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    openshift.io/cluster-monitoring: "true"
  name: openshift-compliance
EOF
oc create -f $PKG-namespace.yaml

cat << EOF > $PKG-groupObject.yaml
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: compliance-operator
  namespace: openshift-compliance
spec:
  targetNamespaces:
  - openshift-compliance
EOF
oc create -f $PKG-groupObject.yaml

cat << EOF > $PKG-subscriptionObject.yaml
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: compliance-operator-sub
  namespace: openshift-compliance
spec:
  channel: "release-0.1"
  installPlanApproval: Automatic
  name: compliance-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
oc create -f $PKG-subscriptionObject.yaml

### Review Status
```
oc get csv -n openshift-compliance 
oc get events -n openshift-compliance -w
oc get pods --field-selector=status.phase=Pending
```

### Update NodeSelector
Depending on where you want to run the Operator:
```
oc patch namespace openshift-compliance -p \
    '{"metadata":{"annotations":{"openshift.io/node-selector":""}}}'

# or (edit: this seems to cause a conflict)
oc patch namespace openshift-compliance --type=merge -p \
    '{"spec":{"nodeSelector": {"node-role.kubernetes.io/infra": ""},"tolerations": [{"effect":"NoSchedule","key": "node-role.kubernetes.io/infra","value": "reserved"},{"effect":"NoExecute","key": "node-role.kubernetes.io/infra","value": "reserved"}]}}'
```

### Cleanup
```
kubectl get namespace "openshift-compliance" -o json \
  | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" \
  | kubectl replace --raw /api/v1/namespaces/openshift-compliance/finalize -f -
```
