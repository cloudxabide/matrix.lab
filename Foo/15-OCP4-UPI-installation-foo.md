# OCP4 UPI installation


| Qty | Machine | OS | vCPU | RAM | Storage |
|:---:|:-------:|:--:|:----:|:---:|:-------:|
| 1   | Bootstrap     | RHCOS | 4 | 16 | 120 |
| 3   | Control Plane | RHCOS | 4 | 16 | 120 |
| 2   | Compute       | RHCOS/RHEL | 4 | 16 | 120 |
| 1   | Remote Worker | RHCOS/RHEL | 4 | 16 | 120 |
| 1   | Load Balancer | RHEL       | 2 | 4  | 120 |

## Create DNS
The following entries already exist for my IPI install
baseDomain: linuxrevolution.com
metadata.name: ocp4-mwn # essentially "clusterName"

api.<clusterName>.<baseDomain>    - 10.10.10.161
*.apps.<clusterName>.<baseDomain> - 10.10.10.162

I did need to add this entry, however (to match "api.<clusterName>..."
```
ipa dnsrecord-add  ocp4-mwn.linuxrevolution.com     'api-int'       --a-rec   10.10.10.161
```

```
ssh rh8-idm-srv01.matrix.lab
kinit admin
ipa dnsrecord-add  matrix.lab     'rh8-ocp-prx'     --a-rec   10.10.10.140
ipa dnsrecord-add  matrix.lab     'bootstrap'       --a-rec   10.10.10.141
ipa dnsrecord-add  matrix.lab     'master-0'        --a-rec   10.10.10.142
ipa dnsrecord-add  matrix.lab     'master-1'        --a-rec   10.10.10.143
ipa dnsrecord-add  matrix.lab     'master-2'        --a-rec   10.10.10.144
ipa dnsrecord-add  matrix.lab     'compute-0'       --a-rec   10.10.10.145
ipa dnsrecord-add  matrix.lab     'compute-1'       --a-rec   10.10.10.146
ipa dnsrecord-add  matrix.lab     'compute-2'       --a-rec   10.10.10.147
ipa dnsrecord-add  matrix.lab     'infra-0'         --a-rec   10.10.10.148
ipa dnsrecord-add  matrix.lab     'infra-1'         --a-rec   10.10.10.149
ipa dnsrecord-add  matrix.lab     'infra-2'         --a-rec   10.10.10.150
ipa dnsrecord-add  10.10.10.in-addr.arpa            140      --ptr-rec rh8-ocp-prx.matrix.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa            141      --ptr-rec bootstrap.matrix.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa            142      --ptr-rec master-0.matrix.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa            143      --ptr-rec master-1.matrix.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa            144      --ptr-rec master-2.matrix.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa            145      --ptr-rec compute-0.matrix.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa            146      --ptr-rec compute-1.matrix.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa            147      --ptr-rec compute-2.matrix.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa            148      --ptr-rec infra-0.matrix.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa            149      --ptr-rec infra-1.matrix.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa            150      --ptr-rec infra-2.matrix.lab.
```

## Create "static-dhcp" entries
Due to the nature of how my lab is setup, I have opted to continue using DHCP, but... the hosts need static entries (mostly because I do not have dynamic updates for DNS enabled)
```
echo "include \"/etc/dhcp/dhcpd.matrix.conf\";" >> /etc/dhcp/dhcpd.conf
cat << EOF > /etc/dhcp/dhcpd.matrix.conf
######################
# 
host rh8-ocp-prx {
 option host-name "rh8-ocp-prx.matrix.lab";
  hardware ethernet 00:50:56:a0:36:00;
  fixed-address 10.10.10.140;
}
host boostrap {
 option host-name "bootstrap.matrix.lab";
  hardware ethernet 00:50:56:a0:36:01;
  fixed-address 10.10.10.141;
}
host master-0 {
 option host-name "master-0.matrix.lab";
  hardware ethernet 00:50:56:a0:36:02;
  fixed-address 10.10.10.142;
}
host master-1 {
 option host-name "master-1.matrix.lab";
  hardware ethernet 00:50:56:a0:36:03;
  fixed-address 10.10.10.143;
}
host master-2 {
 option host-name "master-2.matrix.lab";
  hardware ethernet 00:50:56:a0:36:04;
  fixed-address 10.10.10.144;
}
host compute-0 {
 option host-name "compute-0.matrix.lab";
  hardware ethernet 00:50:56:a0:36:05;
  fixed-address 10.10.10.145;
}
host compute-1 {
 option host-name "compute-1.matrix.lab";
  hardware ethernet 00:50:56:a0:36:06;
  fixed-address 10.10.10.146;
}
host compute-2 {
 option host-name "compute-2.matrix.lab";
  hardware ethernet 00:50:56:a0:36:07;
  fixed-address 10.10.10.147;
}
host infra-0 {
 option host-name "infra-0.matrix.lab";
  hardware ethernet 00:50:56:a0:36:08;
  fixed-address 10.10.10.148;
}
host infra-1 {
 option host-name "infra-1.matrix.lab";
  hardware ethernet 00:50:56:a0:36:09;
  fixed-address 10.10.10.149;
}
host infra-2 {
 option host-name "infra-2.matrix.lab";
  hardware ethernet 00:50:56:a0:36:0a;
  fixed-address 10.10.10.150;
}
EOF
systemctl restart dhcpd
```


## Build the HAProxy Node
Deploy a RHEL 8 VM (RH8-OCP-PRX) in vSphere, using the MAC address defined on your DHCP server and Minimal Install

### Add 2 x VIPs (api/api-int and *.apps)
CONNECTION=ens192
nmcli con mod "$CONNECTION" ipv4.addresses "10.10.10.161/24,10.10.10.162/24"
nmcli conn up "$CONNECTION" 

subscription-manager register --auto-attach
yum -y install haproxy wget
setsebool -P haproxy_connect_any on

### Configue haproxy 
cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/etc_haproxy_haproxy.cfg -O /etc/haproxy/haproxy.cfg
restorecon /etc/haproxy/haproxy.cfg
systemctl enable haproxy --now

CLUSTERNAME=ocp4-mwn
DOMAINNAME=linuxrevolution.com

for HOST in api-int api test.apps
do 
  dig +noall +answer @10.10.10.121 $HOST.$CLUSTERNAME.$DOMAINNAME
done

DOMAINNAME=matrix.lab
for HOST in master-0 master-1 master-2 bootstrap compute-0 compute-1 compute-2
do
  ANSWER=$(dig +noall +answer @10.10.10.121 $HOST.$DOMAINNAME)
  REVERSE=$(dig +noall +answer @10.10.10.121 -x $(echo $ANSWER | awk '{ print $5 }'))
  echo "$ANSWER |* should match *| $REVERSE"
done

DEFAULTZONE=$(firewall-cmd --get-default-zone)
firewall-cmd --zone=${DEFAULTZONE} --permanent --add-port={80/tcp,443/tcp,22623/tcp,6443/tcp,1936/tcp}
firewall-cmd --reload
firewall-cmd --runtime-to-permanent
firewall-cmd --list-ports
firewall-cmd --list-all

nmap -p 80,443,6443,22623,1936  10.10.10.161
nmap -p 80,443,6443,22623,1936  10.10.10.162


Browse to Edit Settings | VM Options | Advanced | Configuration Parameters | EDIT CONFIGURATION...
guestinfo.ignition.config.data
guestinfo.ignition.config.data.encoding base64
disk.EnableUUID TRUE

# run this twice (once for masters, then for compute?)
for CERT in $(oc get csr | grep Pend | awk '{ print $1 }'); do oc adm certificate approve $CERT; done

# References
https://docs.openshift.com/container-platform/4.10/installing/installing_bare_metal/installing-bare-metal.html  
https://docs.openshift.com/container-platform/4.10/installing/installing_bare_metal/installing-bare-metal.html#installation-three-node-cluster_installing-bare-metal  
https://docs.openshift.com/container-platform/4.10/installing/installing_bare_metal/installing-bare-metal.html#installation-approve-csrs_installing-bare-metal  
