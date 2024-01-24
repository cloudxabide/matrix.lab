# Delete OpenShift Cluster without metadata.json

## Purpose
I created this so that I am able to delete a cluster which I may not have the metadata.json file for.  As you can see, it depends on a kubernetes parameter set to "owned" (vs shared).  I'll update this later to deal with a "shared cluster"

## Caveats:

* the openshift-install command does not care what profile you have set in your login session.  It will default to... default.  Make sure you validate which account your "aws cli commands" are getting executed against.
* This process *assumes* quite a few things.  But... they are fair assumptions and likely will get you through the process.

## Process

```
CLUSTER_NAME=testcluster
REGION=us-east-1
CLOUD_PROVIDER=aws

CLUSTER_ID=$(oc get clusterversion -o jsonpath='{.items[].spec.clusterID}{"\n"}')
INFRA_ID=$(oc get infrastructure -o jsonpath='{.items[].status.infrastructureName}{"\n"}')

echo "{\"clusterName\":\"${CLUSTER_NAME}\",\"clusterID\":\"${CLUSTER_ID}\",\"infraID\":\"${INFRA_ID}\",\"${CLOUD_PROVIDER}\":{\"region\":\"${REGION}\",\"identifier\":[{\"kubernetes.io/cluster/${INFRA_ID}\":\"owned\"}]}}" > metadata.json

./openshift-install destroy cluster --log-level=debug
```

