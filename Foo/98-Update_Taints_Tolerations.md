# Update Taints and Tolerations

As part of a "default" cluster build, I think the following should be considered: ODF, ACS, Quay, etc... on "Infra Nodes" 

The Infra Nodes is where the challenge is introduced.  As they are tainted to only allow "node-selector: infra", you need to add that toleration to your "infra workloads".

I believe there are 2 places to do so, and 2 ways, as well.

## Methods

### Inline Update/Modification
An inline update is my preferred method, using either "oc patch" or "oc annotate".  
TODO:  explain the difference between patch and annotate.

A patch seem to be the solution when an object has a way to accomodate a resource definition natively.  
Annotations are a mechanism to enforce behavior when the object does not have the native capability.  I tend to think more often annotations will be used (vs updating the spec: section)  

#### Schedule the ingress controller to run on Infra nodes 
(and tolerate the infra taints) - using spec:nodePlacement:nodeSelector
```
spec:  
  nodePlacement:  
    nodeSelector: <value>  
```

```
oc patch ingresscontroller/default -n  openshift-ingress-operator  --type=merge -p '{"spec":{"nodePlacement": {"nodeSelector": {"matchLabels": {"node-role.kubernetes.io/infra": ""}},"tolerations": [{"effect":"NoSchedule","key": "node-role.kubernetes.io/infra","value": "reserved"},{"effect":"NoExecute","key": "node-role.kubernetes.io/infra","value": "reserved"}]}}}'
```

#### Schedule the Registry to run on Infra nodes 
(and tolerate the infra taints) - using spec:nodeSelector
```
spec:  
  nodeSelector: <value>  
```

```
oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge -p '{"spec":{"nodeSelector": {"node-role.kubernetes.io/infra": ""},"tolerations": [{"effect":"NoSchedule","key": "node-role.kubernetes.io/infra","value": "reserved"},{"effect":"NoExecute","key": "node-role.kubernetes.io/infra","value": "reserved"}]}}'
```

#### Update node-selector for Namespace
```
metadata:  
  annotations:  
    openshift.io/node-selector: ""  
```

```
oc annotate namespace openshift-storage openshift.io/node-selector=
```

### Resource Types which may be modified

```
oc edit configs.imageregistry.operator.openshift.io/cluster
```

# Change the following 
```
  storage: {}
```
to
```
  storage:
    pvc:
      claim: image-registry-pvc
```

## Locations to update
metadata:  
```
oc edit configs.imageregistry.operator.openshift.io/cluster
.
..
...
metadata:
  annotations:
    openshift.io/node-selector: ""
    scheduler.alpha.kubernetes.io/defaultTolerations: |-
      [{"operator": "Exists", "effect": "NoSchedule", "key": "node-role.kubernetes.io/infra"},
        {"operator": "Exists", "effect": "NoExecute", "key":
      "node-role.kubernetes.io/infra"} ]
```
spec:
```
oc edit ingresscontroller/default -n openshift-ingress-operator
.
..
...
spec:
  [...]
  nodePlacement:
    nodeSelector:
      matchLabels:
        node-role.kubernetes.io/infra: ""
    tolerations:
    - effect: NoSchedule
      key: node-role.kubernetes.io/infra
      value: reserved
    - effect: NoExecute
      key: node-role.kubernetes.io/infra
      value: reserved
```
