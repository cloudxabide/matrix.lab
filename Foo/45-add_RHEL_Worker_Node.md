# Adding a RHEL Compute Node to a Cluster

NOTES:  
* I have an Ansible user (mansible - "My Ansible") in my environment.  Therefore, I run my install as that user, from the bastion with the appropriate configuration (NOPASSWD: ALL, etc..)

## Setup the "bastion" System (RHEL 7.9 Bastion)
```
subscription-manager register 
subscription-manager list --available --matches "Red Hat OpenShift Container Platform"
subscription-manager attach --pool=

subscription-manager repos \
   --disable="*" \
   --enable="rhel-7-server-rpms" \
   --enable="rhel-7-server-extras-rpms" \
   --enable="rhel-7-server-ansible-2.9-rpms" \
   --enable="rhel-7-server-ose-4.10-rpms"

yum -y install openshift-ansible openshift-clients jq
yum -y update && shutdown now -r

wget <path to machineconfigpool>
# This does not work (you cannot mix "cloud providers" (vSphere and Bare Metal, in this case))
#oc apply -f machineconfigpool-vsphere-ocp4-mwn.linuxrevolution.com-worker.rhel.yaml

```

## Setup the RHEL Compute Node (RHEL 8.4 Worker)
```
subscription-manager register
subscription-manager list --available --matches "Red Hat OpenShift Container Platform"
subscription-manager attach --pool=
# if node is AWS, [root@ip-10-64-0-35 ~]# subscription-manager config --rhsm.manage_repos=1
subscription-manager repos \
 --disable="*" \
 --enable="rhel-8-for-x86_64-baseos-rpms" \
 --enable="rhel-8-for-x86_64-appstream-rpms" \
 --enable="rhocp-4.10-for-rhel-8-x86_64-rpms" \
 --enable="fast-datapath-for-rhel-8-x86_64-rpms"
systemctl disable --now firewalld.service
yum -y install wget
yum -y update && shutdown now -r

# if node is AWS, CONNECTION="System eth0"; nmcli con modify "$CONNECTION" ipv4.dns "10.10.10.121"; nmcli con modify "$CONNECTION" +ipv4.dns "10.10.10.122"; nmcli conn modify "System eth0" ipv4.ignore-auto-dns yes; systemctl restart NetworkManager


## The following is/was created to Trust the self-signed certs from the API
OCP4APIS="api.ocp4-mwn.linuxrevolution.com api-int.ocp4-mwn.linuxrevolution.com"
OCP4APIPORT=6443
for OCP4API in $OCP4APIS
do 
  echo "NOTE (endpoint): $OCP4API"
  THISCERT=$OCP4API.pem
  echo | openssl s_client -connect $OCP4API:$OCP4APIPORT -servername $OCP4API  | sed -n /BEGIN/,/END/p > $THISCERT
  openssl x509 -in $THISCERT -noout -text | grep Issuer
  openssl x509 -noout -fingerprint -in $THISCERT
  #cp $THISCERT /etc/pki/ca-trust/source/anchors
  #update-ca-trust enable; update-ca-trust extract

  cd /etc/pki/tls/certs/
  cp ~/$THISCERT .
  ln -sv $THISCERT $(openssl x509  -noout -hash -in $THISCERT).0
done

for OCP4API in $OCP4APIS
do 
  echo "NOTE (endpoint): $OCP4API"
  echo | openssl s_client -showcerts -connect $OCP4API:$OCP4APIPORT
  wget https://$OCP4API:22623/config/master
done

```

## Add Node (RHEL 7.9 Bastion)
```
ssh-copyid mansible@sati.matrix.lab

[ ! -f ~/.ssh/id_rsa ] && echo | ssh-keygen -trsa -b2048 -N ''
OCP4API="api.ocp4-mwn.linuxrevolution.com"
OCP4APIPORT=6443
OCUSER=""
OCPASSWORD=""
oc login --username=$OCUSER  --password=$OCPASSWORD  --server=api.ocp4-mwn.linuxrevolution.com:6443
cat ~/.kube/config

cat << EOF > add_rhel_compute_nodes.yaml
[all:vars]
ansible_user=mansible
ansible_become=True

openshift_kubeconfig_path="~/.kube/config"
# Per 5993151 (use the following if you somehow alerady have an MCP to utilize)
#openshift_node_machineconfigpool=worker-rhel

[new_workers]
sati.matrix.lab
EOF 
# NOTE: you need to login to the oc cli prior to running the scaleup
# oc login --username=ocpadmin --password=$OCPASSWORD --server=api.ocp4-mwn.linuxrevolution.com:6443
cd /usr/share/ansible/openshift-ansible
ansible-playbook -i ~/add_rhel_compute_nodes.yaml playbooks/scaleup.yml

for CERT in $(oc get csr | awk '{ print $1 }'); do oc adm certificate approve $CERT; done

```

## Reference
https://docs.openshift.com/container-platform/4.10/machine_management/adding-rhel-compute.html
https://access.redhat.com/solutions/599315sh
