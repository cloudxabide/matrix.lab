# Resizing Nodes

This is a bit of a mystery which is not well documented (from what I can find).

There are Nodes.. and there are Machines.

Machine = essentially the VM.  It is the reference that OCP is aware of to identify a system  
Node = provisioned Machine.  A Node means that the machine has been provisioned as part of the cluster.  


for NODE in `oc get nodes | grep odf | awk '{ print $1 }'`; 
do 
  echo $NODE
  echo "oc delete node $NODE; sleep 300"
  oc delete node $NODE; sleep 300
  echo "oc delete machine $NODE; sleep 500"
  oc delete machine $NODE; sleep 500
 
  # Need to figure out a loop here to wait for the new Machine/Node to join the cluster and be "Ready"
  echo "while true; do oc get nodes | grep NotReady; sleep 30; done"
done
