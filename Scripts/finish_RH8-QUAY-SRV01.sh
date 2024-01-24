#!/bin/bash

nmcli conn modify "ens192" ipv4.ignore-auto-dns yes 
nmcli conn modify "ens192" ipv4.dns "10.10.10.122 10.10.10.121 8.8.4.4"
systemctl restart NetworkManager
echo "`hostname -i` quay.matrix.lab quay" >> /etc/hosts

subscription-manager register
subscription-manager refresh
subscription-manager list --available  --matches "Red Hat Quay Enterprise"

systemctl enable --now cockpit.socket
insights-client --register
sudo yum install -y podman
sudo yum module install -y container-tools

podman login registry.redhat.io

firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp  
firewall-cmd --permanent --add-port=5432/tcp 
firewall-cmd --permanent --add-port=5433/tcp  
firewall-cmd --permanent --add-port=6379/tcp 
firewall-cmd --reload


parted -s /dev/sdb mklabel gpt mkpart pri xfs 2048s 100%
pvcreate /dev/sdb1
vgcreate vg_quay /dev/sdb1
lvcreate -L10g -n lv_postgres vg_quay
mkfs.xfs /dev/mapper/vg_quay-lv_postgres
mkdir /var/lib/pgsql/
cp /etc/fstab /etc/fstab.bak-`date +%F`
echo "/dev/mapper/vg_quay-lv_postgres /var/lib/pgsql/ xfs defaults 1 1" >> /etc/fstab
mount -a
restorecon -RFvv /var/lib/pgsql/

QUAY=/var/lib/pgsql

mkdir -p $QUAY/postgres-quay
setfacl -m u:26:-wx $QUAY/postgres-quay

podman pull registry.redhat.io/rhel8/postgresql-10:1
podman run -d --rm --name postgresql-quay \ 
-e POSTGRESQL_USER=quayuser \
-e POSTGRESQL_PASSWORD=quaypass \
-e POSTGRESQL_DATABASE=quay \
-e POSTGRESQL_ADMIN_PASSWORD=adminpass \ 
-p 5432:5432 \
-v $QUAY/postgres-quay:/var/lib/pgsql/data:Z \ 
registry.redhat.io/rhel8/postgresql-10:1

podman exec -it postgresql-quay /bin/bash -c 'echo "CREATE EXTENSION IF NOT EXISTS pg_trgm" | psql -d quay -U postgres'

podman run -d --rm --name redis \
  -p 6379:6379 \
  -e REDIS_PASSWORD=strongpassword \
  registry.redhat.io/rhel8/redis-5:1

podman run --rm -it --name quay_config -p 80:8080 -p 443:8443 quay.io/projectquay/quay:qui-gon config quaysecret 

