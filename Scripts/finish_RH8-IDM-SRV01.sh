#!/bin/bash

systemctl enable chronyd --now

cat << EOF >> /etc/hosts

# Red Hat Identity Management Servers
10.10.10.121 rh8-idm-srv01.matrix.lab rh8-idm-srv01
10.10.10.122 rh8-idm-srv02.matrix.lab rh8-idm-srv02
EOF

# You liklely still need to cut-and-paste this thing in to a shell.
#   But... it IS close to being executable as a stand-alone!
ADMINPASSWD='NotAPassword'

# Update the firewall settings according to installation doc
DEFAULTZONE=$(firewall-cmd --get-default-zone)
firewall-cmd --zone=${DEFAULTZONE} --permanent --add-port={80/tcp,443/tcp,389/tcp,636/tcp,88/tcp,88/udp,464/tcp,464/udp,53/tcp,53/udp,123/udp}
firewall-cmd --permanent --zone=${DEFAULTZONE} --add-service={ntp,freeipa-ldap,freeipa-ldaps,dns} 
firewall-cmd --reload
firewall-cmd --runtime-to-permanent
firewall-cmd --list-ports
firewall-cmd --list-all

subscription-manager status || { echo "System not registered to Red Hat.  Exiting...."; exit 9; }

yum -y module enable idm:DL1
yum -y distro-sync
yum -y module install idm:DL1/{dns,client}

# The following are the installation tasks, which are different depending on the host
case `hostname -s` in
  # MASTER - Run this first...
  rh8-idm-srv01)

IPA_OPTIONS="
--realm=MATRIX.LAB
--domain=matrix.lab
--ds-password=$ADMINPASSWD
--admin-password=$ADMINPASSWD
--hostname=rh8-idm-srv01.matrix.lab
--ip-address=10.10.10.121
--setup-dns --no-forwarders
--mkhomedir
--unattended"

CERTIFICATE_OPTIONS="
--subject="

echo "NOTE:  You are likely going to see a warning/notice about entropy"
echo "  in another window, run:  rngd -r /dev/urandom -o /dev/random -f"

echo "ipa-server-install -U $IPA_OPTIONS $CERTIFICATE_OPTIONS"
ipa-server-install -U $IPA_OPTIONS $CERTIFICATE_OPTIONS
echo $ADMINPASSWD | kinit admin
klist

echo "You will likely want to add the entry to the RH7IDM01 DNS zone for RH7IDM02 before this next step"
ipa dnszone-add 10.10.10.in-addr.arpa.  # "public"
ipa dnszone-add 11.10.10.in-addr.arpa.  # "public" second /24 CIDR
ipa dnszone-add 10.16.172.in-addr.arpa. # storage1
ipa dnszone-add 11.16.172.in-addr.arpa. # storage2

ipa dnsrecord-add matrix.lab rh8-idm-srv01 --a-rec 10.10.10.121
ipa dnsrecord-add matrix.lab rh8-idm-srv02 --a-rec 10.10.10.122
ipa dnsrecord-add 10.10.10.in-addr.arpa 121 --ptr-rec rh8-idm-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 122 --ptr-rec rh8-idm-srv02.matrix.lab.

  ;;
  rh8-idm-srv02)
    ipa-replica-install --principal admin --realm=MATRIX.LAB --domain=matrix.lab --setup-dns --no-forwarders --admin-password ${ADMINPASSWD}
    echo $ADMINPASSWD | ipa-ca-install
    # Or.. use the random password from above
    #ipa-replica-install --principal admin --realm=MATRIX.LAB --domain=matrix.lab --setup-dns --no-forwarders --password ${ADMINPASSWD}
  ;;
  *)
    echo "DUDE!  This system is not part of the borg"
    exit 0
 ;;
esac

case `hostname -s` in 
  rh8-idm-srv01)

###############
# User/Group Management
###############
echo $ADMINPASSWD | ipa user-add morpheus --uid=1001 --gidnumber=1001 --first=Morpheus --last=McChicken --email=morpheus@matrix.lab --homedir=/home/morpheus --shell=/bin/bash --password
echo $ADMINPASSWD | ipa user-add mansible --uid=1002 --gidnumber=1002 --first=My --last=Ansbile --email=mansible@matrix.lab --homedir=/home/mansible --shell=/bin/bash --password
echo $ADMINPASSWD | ipa user-add jradtke --uid=2025 --gidnumber=2025 --first=James --last=Radtke --manager=Morpheus --email=jradtke@matrix.lab --homedir=/home/jradtke --shell=/bin/bash --password
echo $ADMINPASSWD | ipa user-add mcolburn --uid=2026 --gidnumber=2026 --first=Mamie --last=Colburn --manager=Morpheus --email=mcolburn@matrix.lab --homedir=/home/mcolburn --shell=/bin/bash --password
ipa user-add ocp-connector --first=OpenShift --last=Connector --gecos="OpenShift Connector" --email=ocp@matrix.lab --homedir=/tmp --shell=/sbin/nologin --random

## NOTE: NEED TO PUT THESE IN TO "ipa" COMMANDS
GROUPS="admins managers"
for GROUP in $GROUPS
do 
  ipa group-add $GROUP
done

# TODO:  get the approach sorted then update this
ipa group-add openshift-admins --desc="OpenShift Administrators"
ipa group-add openshift-users --desc="OpenShift Users"
ipa group-add-member openshift-admins --users=jradtke 
ipa group-add-member openshift-users  --users=jradtke --users=morpheus 

###############
## Service Account Management
###############
# For RHV
ipa group-add kvm --gid 36
ipa user-add vdsm --uid=36 --gidnumber=36 --first=Virtualization --last=Manager --gecos="Node Virtualization Manager" --email=vdsm@matrix.lab --homedir=/var/lib/vdsm --shell=/sbin/nologin --random
ipa user-add qemu --uid=107 --gidnumber=107 --first=qemu --last=user --gecos="qemu user" --email=qemu@matrix.lab --homedir=/ --shell=/sbin/nologin --random
 
###############
# PHYSICAL NODES
###############
# Network Gear
ipa dnsrecord-add matrix.lab sophos-xg          --a-rec 10.10.10.1
ipa dnsrecord-add matrix.lab firewall           --cname-rec='sophos-xg.matrix.lab.'
ipa dnsrecord-add matrix.lab gateway            --cname-rec='sophos-xg.matrix.lab.'
ipa dnsrecord-add matrix.lab cisco-sg300-28     --a-rec 10.10.10.2
ipa dnsrecord-add matrix.lab cisco-lgs326-26    --a-rec 10.10.10.3
# Physical Computers
ipa dnsrecord-add matrix.lab zion               --a-rec 10.10.10.10
ipa dnsrecord-add matrix.lab zion-storage10       --a-rec 172.16.10.10
ipa dnsrecord-add matrix.lab zion-storage11       --a-rec 172.16.11.10

ipa dnsrecord-add matrix.lab neo                --a-rec 10.10.10.11
ipa dnsrecord-add matrix.lab neo-storage10        --a-rec 172.16.10.11
ipa dnsrecord-add matrix.lab neo-storage11        --a-rec 172.16.11.11
ipa dnsrecord-add matrix.lab neo-ilom           --a-rec 10.10.10.21
ipa dnsrecord-add matrix.lab neo-guest          --a-rec 10.10.10.31

ipa dnsrecord-add matrix.lab trinity            --a-rec 10.10.10.12
ipa dnsrecord-add matrix.lab trinity-storage10    --a-rec 172.16.10.12
ipa dnsrecord-add matrix.lab trinity-storage11    --a-rec 172.16.11.12
ipa dnsrecord-add matrix.lab trinity-ilom       --a-rec 10.10.10.22
ipa dnsrecord-add matrix.lab trinity-guest      --a-rec 10.10.10.32

ipa dnsrecord-add matrix.lab morpheus           --a-rec 10.10.10.13
ipa dnsrecord-add matrix.lab morpheus-storage10 --a-rec 172.16.10.13
ipa dnsrecord-add matrix.lab morpheus-storage11 --a-rec 172.16.11.13
ipa dnsrecord-add matrix.lab morpheus-ilom      --a-rec 10.10.10.23
ipa dnsrecord-add matrix.lab morpheus-guest     --a-rec 10.10.10.33

ipa dnsrecord-add matrix.lab dozer		--a-rec 10.10.10.14
ipa dnsrecord-add matrix.lab dozer-storage10    --a-rec 172.16.10.14
ipa dnsrecord-add matrix.lab dozer-storage11    --a-rec 172.16.11.14
ipa dnsrecord-add matrix.lab dozer-guest        --a-rec 10.10.10.34

ipa dnsrecord-add matrix.lab tank               --a-rec 10.10.10.15
ipa dnsrecord-add matrix.lab tank-storage10     --a-rec 172.16.10.15
ipa dnsrecord-add matrix.lab tank-storage11     --a-rec 172.16.11.15
ipa dnsrecord-add matrix.lab tank-guest         --a-rec 10.10.10.35

ipa dnsrecord-add matrix.lab cypher		--a-rec 10.10.10.16
ipa dnsrecord-add matrix.lab cypher-storage     --a-rec 172.16.10.16
ipa dnsrecord-add matrix.lab cypher-guest       --a-rec 10.10.10.36

ipa dnsrecord-add matrix.lab sati               --a-rec 10.10.10.17
ipa dnsrecord-add matrix.lab sati-storage       --a-rec 172.16.10.17

ipa dnsrecord-add matrix.lab apoc		--a-rec 10.10.10.18
ipa dnsrecord-add matrix.lab apoc-storage10     --a-rec 172.16.10.18
ipa dnsrecord-add matrix.lab apoc-storage11     --a-rec 172.16.11.18

ipa dnsrecord-add matrix.lab seraph             --a-rec 10.10.10.19
ipa dnsrecord-add matrix.lab seraph-storage10   --a-rec 172.16.10.19
ipa dnsrecord-add matrix.lab seraph-storage11   --a-rec 172.16.11.19
ipa dnsrecord-add matrix.lab storage            --cname-rec='seraph.matrix.lab.'
ipa dnsrecord-add matrix.lab nas                --cname-rec='seraph.matrix.lab.'
ipa dnsrecord-add matrix.lab freenas            --cname-rec='seraph.matrix.lab.'

# REVERSE LOOKUP 
# 10.10.10
ipa dnsrecord-add 10.10.10.in-addr.arpa 1       --ptr-rec sophos-xg.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 2       --ptr-rec cisco-sg300-28.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 3       --ptr-rec cisco-lgs326-26.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 10      --ptr-rec zion.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 11      --ptr-rec neo.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 12      --ptr-rec trinity.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 13      --ptr-rec morpheus.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 14      --ptr-rec dozer.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 15      --ptr-rec tank.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 16      --ptr-rec cypher.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 18      --ptr-rec apoc.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 19      --ptr-rec seraph.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 21      --ptr-rec neo-ilom.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 22      --ptr-rec trinity-ilom.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 23      --ptr-rec morpheus-ilom.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 31      --ptr-rec neo-guest.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 32      --ptr-rec trinity-guest.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 33      --ptr-rec morpheus-guest.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 34      --ptr-rec dozer-guest.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 35      --ptr-rec tank-guest.matrix.lab.

# 10.16.172
ipa dnsrecord-add 10.16.172.in-addr.arpa 10     --ptr-rec zion-storage10.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 11     --ptr-rec neo-storage10.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 12     --ptr-rec trinity-storage10.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 13     --ptr-rec morpheus-storage10.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 14     --ptr-rec dozer-storage10.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 15     --ptr-rec tank-storage10.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 16     --ptr-rec cypher-storage10.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 18     --ptr-rec apoc-storage10.matrix.lab.
ipa dnsrecord-add 10.16.172.in-addr.arpa 19     --ptr-rec seraph-storage10.matrix.lab.

ipa dnsrecord-add 11.16.172.in-addr.arpa 10     --ptr-rec zion-storage11.matrix.lab.
ipa dnsrecord-add 11.16.172.in-addr.arpa 11     --ptr-rec neo-storage11.matrix.lab.
ipa dnsrecord-add 11.16.172.in-addr.arpa 12     --ptr-rec trinity-storage11.matrix.lab.
ipa dnsrecord-add 11.16.172.in-addr.arpa 13     --ptr-rec morpheus-storage11.matrix.lab.
ipa dnsrecord-add 11.16.172.in-addr.arpa 14     --ptr-rec dozer-storage11.matrix.lab.
ipa dnsrecord-add 11.16.172.in-addr.arpa 15     --ptr-rec tank-storage11.matrix.lab.
ipa dnsrecord-add 11.16.172.in-addr.arpa 16     --ptr-rec cypher-storage11.matrix.lab.
ipa dnsrecord-add 11.16.172.in-addr.arpa 18     --ptr-rec apoc-storage11.matrix.lab.
ipa dnsrecord-add 11.16.172.in-addr.arpa 19     --ptr-rec seraph-storage11.matrix.lab.
###############
# Utility Hosts 
###############
# Utility Hosts 
###############
ipa dnsrecord-add matrix.lab rh8-util-srv01     --a-rec 10.10.10.100
ipa dnsrecord-add matrix.lab rh7-util-srv01     --a-rec 10.10.10.101
ipa dnsrecord-add matrix.lab rh8-sat6-srv01     --a-rec 10.10.10.102
ipa dnsrecord-add matrix.lab rh8-sat6-cap01     --a-rec 10.10.10.103
ipa dnsrecord-add matrix.lab rh7-rhv4-mgr01     --a-rec 10.10.10.104
ipa dnsrecord-add matrix.lab rh8-sat6-srv02     --a-rec 10.10.10.106
ipa dnsrecord-add matrix.lab rh8-ans-srv01      --a-rec 10.10.10.107
ipa dnsrecord-add matrix.lab rh8-quay-srv01      --a-rec 10.10.10.108
ipa dnsrecord-add matrix.lab quay               --cname-rec='rh8-quay-srv01'
ipa dnsrecord-add matrix.lab rh8-util-srv02     --a-rec 10.10.10.109
ipa dnsrecord-add matrix.lab rh8-lms-srv01      --a-rec 10.10.10.110
ipa dnsrecord-add matrix.lab librenms           --cname-rec='rh8-lms-srv01'
ipa dnsrecord-add matrix.lab rh8-splunk-srv01      --a-rec 10.10.10.111
ipa dnsrecord-add matrix.lab splunk            --cname-rec='rh8-splunk-srv01'
ipa dnsrecord-add matrix.lab f5-bigip-mgmt-01  --a-rec 10.10.10.112
ipa dnsrecord-add matrix.lab f5-bigip-ctrl-01  --a-rec 10.10.10.113
ipa dnsrecord-add matrix.lab f5-bigip-data-01  --a-rec 10.10.10.114
ipa dnsrecord-add matrix.lab f5-bigip-data-02  --a-rec 10.10.10.115
ipa dnsrecord-add matrix.lab vmw-vcenter6       --a-rec 10.10.10.130
ipa dnsrecord-add matrix.lab win-2019-srv01      --a-rec 10.10.10.131
ipa dnsrecord-add matrix.lab vmw-vcenter7       --a-rec 10.10.10.132

ipa dnsrecord-add 10.10.10.in-addr.arpa 100     --ptr-rec rh8-util-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 101     --ptr-rec rh7-util-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 102     --ptr-rec rh8-sat6-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 103     --ptr-rec rh8-sat6-cap01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 104     --ptr-rec rh7-rhv4-mgr01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 106     --ptr-rec rh8-sat6-srv02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 107     --ptr-rec rh8-ans-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 108     --ptr-rec rh8-quay-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 109     --ptr-rec rh8-util-srv02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 110     --ptr-rec rh8-lms-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 111     --ptr-rec rh8-splunk-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 112     --ptr-rec f5-bigip-mgmt-01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 113     --ptr-rec f5-bigip-ctrl-01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 114     --ptr-rec f5-bigip-data-01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 115     --ptr-rec f5-bigip-data-02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 130     --ptr-rec vmw-vcenter6.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 131     --ptr-rec win-2019-srv01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 132     --ptr-rec vmw-vcenter7.matrix.lab.
###############
# VPN Endpoints 
###############
ipa dnsrecord-add matrix.lab vpn-guest-01       --a-rec 10.10.10.241
ipa dnsrecord-add matrix.lab vpn-guest-02       --a-rec 10.10.10.242
ipa dnsrecord-add matrix.lab vpn-guest-03       --a-rec 10.10.10.243
ipa dnsrecord-add 10.10.10.in-addr.arpa 241     --ptr-rec vpn-guest-01.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 242     --ptr-rec vpn-guest-02.matrix.lab.
ipa dnsrecord-add 10.10.10.in-addr.arpa 243     --ptr-rec vpn-guest-03.matrix.lab.

# Add an internal reference that refers to the external zone
### LINUXREVOLUTION.com
ipa dnszone-add linuxrevolution.com --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true --skip-overlap-check
ipa dnszone-add cloudxabide.com --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true --skip-overlap-check

# DHCP entries (used by OCP4)
#BASE_DOMAIN=linuxrevolution.com
BASE_DOMAIN=matrix.lab
for IP in `seq 192 240` 
do
  ipa dnsrecord-add ${BASE_DOMAIN}. dhcp-${IP} --a-rec 10.10.10.${IP}
  ipa dnsrecord-add 10.10.10.in-addr.arpa $IP --ptr-rec dhcp-${IP}.${BASE_DOMAIN}.
  sleep 1
done

######
aws() {
BASE_DOMAIN=ec2.internal
for IP in `seq 1 254`
do 
  ipa dnsrecord-add ${BASE_DOMAIN}. ip-10-64-0-${IP} --a-rec 10.64.0.${IP}
done
}

eksa() {
# EKSA - EKS Anywhere
ipa dnszone-add    eksa.matrix.lab      --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add    apps.ocp4-sno.matrix.lab --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnsrecord-add  eksa.matrix.lab                   'eks-admin'     --a-rec   10.10.11.10
ipa dnsrecord-add  eksa.matrix.lab                   'eks-host01'     --a-rec   10.10.11.11
ipa dnsrecord-add  eksa.matrix.lab                   'eks-host02'     --a-rec   10.10.11.12
ipa dnsrecord-add  eksa.matrix.lab                   'eks-host03'     --a-rec   10.10.11.13
ipa dnsrecord-add  11.10.10.in-addr.arpa       10   --ptr-rec eks-admin.eksa.matrix.lab.
ipa dnsrecord-add  11.10.10.in-addr.arpa       11   --ptr-rec eks-host01.eksa.matrix.lab.
ipa dnsrecord-add  11.10.10.in-addr.arpa       12   --ptr-rec eks-host02.eksa.matrix.lab.
ipa dnsrecord-add  11.10.10.in-addr.arpa       13   --ptr-rec eks-host03.eksa.matrix.lab.
}

  
ocp4() {
#ipa dnszone-add ocp4-mwn.matrix.lab      --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
#ipa dnszone-add apps.ocp4-mwn.matrix.lab --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
#ipa dnszone-add proles.ocp4-mwn.matrix.lab --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
#ipa dnsrecord-add   ocp4-mwn.matrix.lab         'api'     --a-rec 10.10.10.161
#ipa dnsrecord-add   apps.ocp4-mwn.matrix.lab    '*'       --a-rec 10.10.10.162
ipa dnsrecord-add   proles.ocp4-mwn.matrix.lab    '*'       --a-rec 10.10.10.162
#ipa dnsrecord-add   10.10.10.in-addr.arpa       161       --ptr-rec api.ocp4-mwn.matrix.lab.
#ipa dnsrecord-add   10.10.10.in-addr.arpa       162       --ptr-rec *.apps.ocp4-mwn.matrix.lab.

# OCP - Primary Cluster
ipa dnszone-add linuxrevolution.com      --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add ocp4-mwn.linuxrevolution.com      --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add apps.ocp4-mwn.linuxrevolution.com --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add proles.ocp4-mwn.linuxrevolution.com --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnsrecord-add   linuxrevolution.com                  '*'       --a-rec   10.10.10.162
ipa dnsrecord-add   ocp4-mwn.linuxrevolution.com         'api'     --a-rec   10.10.10.161
ipa dnsrecord-add   apps.ocp4-mwn.linuxrevolution.com    '*'       --a-rec   10.10.10.162
ipa dnsrecord-add   proles.ocp4-mwn.linuxrevolution.com  '*'       --a-rec   10.10.10.163
ipa dnsrecord-add   cloudxabide.com                      '*'       --a-rec   10.10.10.162
ipa dnsrecord-add   cloudxabide.com                      cloudxabide.com.  --a-rec   10.10.10.162
ipa dnsrecord-add   10.10.10.in-addr.arpa                161       --ptr-rec api.ocp4-mwn.linuxrevolution.com.
ipa dnsrecord-add   10.10.10.in-addr.arpa                162       --ptr-rec *.apps.ocp4-mwn.linuxrevolution.com.
ipa dnsrecord-add   10.10.10.in-addr.arpa                163       --ptr-rec *.proles.ocp4-mwn.linuxrevolution.com.

# OCP - RHACM Cluster
ipa dnszone-add    linuxrevolution.com               --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add    ocp4-acm.linuxrevolution.com      --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add    apps.ocp4-acm.linuxrevolution.com --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnsrecord-add  ocp4-acm.linuxrevolution.com      'api'     --a-rec   10.10.10.171
ipa dnsrecord-add  apps.ocp4-acm.linuxrevolution.com '*'       --a-rec   10.10.10.172
ipa dnsrecord-add  10.10.10.in-addr.arpa              171      --ptr-rec api.ocp4-acm.linuxrevolution.com.
ipa dnsrecord-add  10.10.10.in-addr.arpa              172      --ptr-rec *.apps.ocp4-acm.linuxrevolution.com.

# OCP - SNO (single node openshift - external)
ipa dnszone-add    ocp4-sno.linuxrevolution.com      --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add    apps.ocp4-sno.linuxrevolution.com --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnsrecord-add  ocp4-sno.linuxrevolution.com      'api'     --a-rec   10.10.10.44
ipa dnsrecord-add  ocp4-sno.linuxrevolution.com      'api-int'     --a-rec   10.10.10.44
ipa dnsrecord-add  apps.ocp4-sno.linuxrevolution.com '*'       --a-rec   10.10.10.44
#ipa dnsrecord-add  10.10.10.in-addr.arpa              44      --ptr-rec api.ocp4-sno.linuxrevolution.com.
#ipa dnsrecord-add  10.10.10.in-addr.arpa              44      --ptr-rec api-int.ocp4-sno.linuxrevolution.com.
#ipa dnsrecord-add  10.10.10.in-addr.arpa              44      --ptr-rec *.apps.ocp4-sno.linuxrevolution.com.

# OCP - SNO (single node openshift - internal only)
ipa dnszone-add    ocp4-sno.matrix.lab      --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add    apps.ocp4-sno.matrix.lab --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnsrecord-add  matrix.lab                   'sno'     --a-rec   10.10.10.44
ipa dnsrecord-add  ocp4-sno.matrix.lab          'api'     --a-rec   10.10.10.44
ipa dnsrecord-add  ocp4-sno.matrix.lab          'api-int' --a-rec   10.10.10.44
ipa dnsrecord-add  apps.ocp4-sno.matrix.lab      '*'      --a-rec   10.10.10.44
# I do NOT add the reverse lookup as this host already has it (10.10.10.44 = sno.matrix.lab)
#ipa dnsrecord-add  10.10.10.in-addr.arpa              44      --ptr-rec api.ocp4-sno.matrix.lab.
#ipa dnsrecord-add  10.10.10.in-addr.arpa              44      --ptr-rec api-int.ocp4-sno.matrix.lab.
#ipa dnsrecord-add  10.10.10.in-addr.arpa              44      --ptr-rec *.apps.ocp4-sno.matrix.lab.

# OCP - SNO (single node openshift - on laptop)
ipa dnszone-add    aperture.lab      --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add    ocp4-sno.aperture.lab      --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add    apps.ocp4-sno.aperture.lab --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnsrecord-add  aperture.lab                 'blackmesa' --a-rec   10.10.10.43
ipa dnsrecord-add  ocp4-sno.aperture.lab        'api'       --a-rec   10.10.10.43
ipa dnsrecord-add  ocp4-sno.aperture.lab        'api-int'   --a-rec   10.10.10.43
ipa dnsrecord-add  apps.ocp4-sno.aperture.lab   '*'         --a-rec   10.10.10.43
#ipa dnsrecord-add  10.10.10.in-addr.arpa              43      --ptr-rec api.ocp4-sno.aperture.lab.
#ipa dnsrecord-add  10.10.10.in-addr.arpa              43      --ptr-rec api-int.ocp4-sno.aperture.lab.
#ipa dnsrecord-add  10.10.10.in-addr.arpa              43      --ptr-rec *.apps.ocp4-sno.aperture.lab.


# jetsons.lab - Edge, AI/ML testing
ipa dnszone-add    jetsons.lab --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnsrecord-add  jetsons.lab     'helios'     --a-rec   10.10.10.50
ipa dnsrecord-add  jetsons.lab     'elroy'     --a-rec   10.10.10.51
ipa dnsrecord-add  jetsons.lab     'judy'      --a-rec   10.10.10.52
ipa dnsrecord-add  jetsons.lab     'jane'      --a-rec   10.10.10.53
ipa dnsrecord-add  jetsons.lab     'george'    --a-rec   10.10.10.54
ipa dnsrecord-add  jetsons.lab     'xavier'    --a-rec   10.10.10.55
ipa dnsrecord-add  jetsons.lab     'jetbot'    --a-rec   10.10.10.56
ipa dnsrecord-add  10.10.10.in-addr.arpa       50   --ptr-rec helios.jetsons.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa       51   --ptr-rec elroy.jetsons.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa       52   --ptr-rec judy.jetsons.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa       53   --ptr-rec jane.jetsons.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa       54   --ptr-rec george.jetsons.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa       55   --ptr-rec xavier.jetsons.lab.
ipa dnsrecord-add  10.10.10.in-addr.arpa       56   --ptr-rec jetbot.jetsons.lab.
ipa dnsrecord-add  jetsons.lab      worker-0    --cname-rec='elroy.jetsons.lab.'
ipa dnsrecord-add  jetsons.lab      worker-1    --cname-rec='judy.jetsons.lab.'
ipa dnsrecord-add  jetsons.lab      master-0    --cname-rec='jane.jetsons.lab.'
ipa dnsrecord-add  jetsons.lab      master-1    --cname-rec='george.jetsons.lab.'

# THIS IS SPECIFIC TO MY HOME - it allows zone-transfer and "host -l matrix.lab" to run
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' 10.10.10.in-addr.arpa
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' 11.10.10.in-addr.arpa
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1;10.10.69.0/24' matrix.lab
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' jetsons.lab
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' linuxrevolution.com
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' ocp4-mwn.linuxrevolution.com
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' apps.ocp4-mwn.linuxrevolution.com
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' proles.ocp4-mwn.linuxrevolution.com
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' ocp4-acm.linuxrevolution.com
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' apps.ocp4-acm.linuxrevolution.com
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' ocp4-sno.linuxrevolution.com
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' apps.ocp4-sno.linuxrevolution.com
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' cloudxabide.com
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' ocp4-sno.aperture.lab
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' apps.ocp4-sno.aperture.lab
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' aperture.lab
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' ocp4-sno.matrix.lab
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' apps.ocp4-sno.matrix.lab
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' matrix.lab
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' eksa.matrix.lab
  ;;
esac

exit 0
 
########################################################################################
########################################################################################
#                                                                                      #
#     FFFFFF    IIIIIII   N      N    IIIIIII    SSS    H      H  EEEEEE   DDDD        #
#     F            I      N N    N       I      S   S   H      H  E        D   D       #
#     F            I      N  N   N       I      S       H      H  E        D    D      #
#     FFFF         I      N   N  N       I       SSS    HHHHHHHH  EEEE     D    D      #
#     F            I      N    N N       I          S   H      H  E        D    D      #
#     F            I      N     NN       I      S   S   H      H  E        D   D       # 
#     F         IIIIIII   N      N    IIIIIII    SSS    H      H  EEEEEE   DDDD        #
#                                                                                      #
########################################################################################
########################################################################################
#  Some update foo for schema/policy
#  ipa pwpolicy-mod global_policy --lockouttime=0

# ldapsearch -x -LLL -D "cn=Directory Manager" -w directory "cn=global_policy"
# uname -n; echo "* * * * * * *"; ipa pwpolicy-show; echo "* * * * *"; ldapsearch -xLLL -D "cn=Directory Manager" -W -b "dc=MATRIX,dc=LAB" uid=jradtke krbloginfailedcount; echo "* * * * "; ipa user-status jradtke 

# If you need to re-install an IDM box...
# ipa-replica-manage del rh7-idm-srv02.matrix.lab --force

# Appendix to meld Satellite 6 in to the fold...
  ## On RH7-IDM-SRV01...
echo $ADMINPASSWD | kinit admin
ipa host-add --desc="Satellite 6" --locality="Washington, DC" --location="LaptopLab" --os="Red Hat Enterprise Linux Server 7" --password=$ADMINPASSWD rh7-sat6-srv01.matrix.lab
ipa service-add HTTP/rh7-sat6-srv01.matrix.lab@matrix.lab

dig SRV _kerberos._tcp.matrix.lab | grep -v \;
dig SRV _ldap._tcp.matrix.lab | grep -v \;

# Example DNS update
; ldap servers
_ldap._tcp		IN SRV 0 100 389	rh7-idm-srv01
_ldap._tcp		IN SRV 0 90  389	rh7-idm-srv02

;kerberos realm
_kerberos		IN TXT MATRIX.LAB

; kerberos servers
_kerberos._tcp		IN SRV 0 100 88		rh7-idm-srv01
_kerberos._udp		IN SRV 0 100 88		rh7-idm-srv01
_kerberos-master._tcp	IN SRV 0 100 88		rh7-idm-srv01
_kerberos-master._udp	IN SRV 0 100 88		rh7-idm-srv01
_kpasswd._tcp		IN SRV 0 100 464	rh7-idm-srv01
_kpasswd._udp		IN SRV 0 100 464	rh7-idm-srv01
_kerberos._tcp          IN SRV 0 90 88         rh7-idm-srv02
_kerberos._udp          IN SRV 0 90 88         rh7-idm-srv02
_kerberos-master._tcp   IN SRV 0 90 88         rh7-idm-srv02
_kerberos-master._udp   IN SRV 0 90 88         rh7-idm-srv02
_kpasswd._tcp           IN SRV 0 90 464        rh7-idm-srv02
_kpasswd._udp           IN SRV 0 90 464        rh7-idm-srv02

; CNAME for IPA CA replicas (used for CRL, OCSP)
ipa-ca			IN A			10.10.10.121
ipa-ca			IN A			10.10.10.122
