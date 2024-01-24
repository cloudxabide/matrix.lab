# OCP4 Troubleshooting

NOTE: this is not intended to be an exhaustive list for troubleshooting.  It is directly related to my own limited install scope.

## Troubleshooting the Install
You can review the progress directly from the bootstrap system

TL;DR:
```
ssh -i ~/.ssh/id_rsa-aperturelab core@192.168.126.10
  journalctl -b -f -u release-image.service -u bootkube.service
```


It appears that initially you will initially see:
* "Golden Image" (rhcos) node
* Masters
* Bootstrap

It is normal to see the API timeouts (around 5 times seems "normal"
```
time="2020-12-02T11:46:22-06:00" level=info msg="Waiting up to 20m0s for the Kubernetes API at https://api.ocp4-mwn.linuxrevolution.com:6443..."
time="2020-12-02T11:46:25-06:00" level=debug msg="Still waiting for the Kubernetes API: Get \"https://api.ocp4-mwn.linuxrevolution.com:6443/version?timeout=32s\": dial tcp 10.10.10.161:6443: connect: no route to host"
time="2020-12-02T11:47:10-06:00" level=debug msg="Still waiting for the Kubernetes API: Get \"https://api.ocp4-mwn.linuxrevolution.com:6443/version?timeout=32s\": dial tcp 10.10.10.161:6443: connect: no route to host"
time="2020-12-02T11:47:55-06:00" level=debug msg="Still waiting for the Kubernetes API: Get \"https://api.ocp4-mwn.linuxrevolution.com:6443/version?timeout=32s\": dial tcp 10.10.10.161:6443: connect: no route to host"
time="2020-12-02T11:48:18-06:00" level=debug msg="Still waiting for the Kubernetes API: Get \"https://api.ocp4-mwn.linuxrevolution.com:6443/version?timeout=32s\": dial tcp 10.10.10.161:6443: connect: connection refused"
time="2020-12-02T11:48:21-06:00" level=info msg="API v1.19.0+d59ce34 up"
```
Then, eventually you will see the worker nodes spinning up.

```
ssh core@(IP OF BOOTSTRAP)
journalctl -b -f -u bootkube.service
```
Also, I find the DHCPD logs to be helpful
Note you should see requests from nodes sending "clustername-clusterID-{master,worker}-randomID"
```
journalctl -f -u dhcpd
Dec 02 12:11:19 rh7-sat6-srv01.matrix.lab dhcpd[9566]: DHCPREQUEST for 10.10.10.199 from 00:50:56:a5:40:2e (ocp4-mwn-kkdz5-worker-rnphr) via ens192

## Login to the Environment

```
oc login -u kubeadmin -p `cat $(find $OCP4_DIR/ -name kubeadmin-password)`  https://api.ocp4-mwn.linuxrevolution.com:6443/
# export KUBECONFIG=/root/OCP4/${OCP4_DIR}/auth/kubeconfig
oc get nodes
```

### Create IAM Manifests
cd $INSTALL_DIR

./openshift-install create install-config --dir=${INSTALL_DIR}
./openshift-install create manifests --dir=${INSTALL_DIR}

## References
https://www.virtuallyghetto.com/2020/07/using-the-new-installation-method-for-deploying-openshift-4-5-on-vmware-cloud-on-aws.html
https://docs.openshift.com/container-platform/4.6/web_console/customizing-the-web-console.html

### Custom Machinesets during IPI install
https://github.com/openshift/installer/blob/master/docs/user/customization.md
https://github.com/openshift/installer/blob/master/docs/user/vsphere/customization.md#machine-pools

## Random foo
```
for IP in `oc get nodes -o wide | awk '{ print $6 }' | grep -v INT`; do ssh core@${IP} "grep proc /proc/cpuinfo"; done
for IP in `oc get nodes -o wide | awk '{ print $6 }' | grep -v INT`; do ssh core@${IP} "uptime"; done
```

```
oc get pods --all-namespaces | egrep -v 'Running' | awk '{ print "oc delete pod " $2 " -n " $1 }' > /tmp/blah
sh /tmp/blah
```
### Clean up between cluster deploys
```
ssh seraph.matrix.lab
rm -rf /mnt/raidZ/nfs-registry/docker
```

```
export KUBECONFIG=$(find ~/OCP4/*acm* -name kubeconfig)
cat $(find ~/OCP4/*acm* -name kubeadmin-password)
oc login -u kubeadmin -p `cat $(find ${HOME}/OCP4/*acm* -name kubeadmin-password)`  https://api.ocp4-acm.linuxrevolution.com:6443/

export KUBECONFIG=$(find ~/OCP4/*mwn* -name kubeconfig)
cat $(find ~/OCP4/*mwn* -name kubeadmin-password)
oc login -u kubeadmin -p `cat $(find ${HOME}/OCP4/*mwn* -name kubeadmin-password)`  https://api.ocp4-mwn.linuxrevolution.com:6443/
