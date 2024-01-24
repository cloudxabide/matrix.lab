#version=RHEL8
# Use text install
text

# Use Network installation media
url --url="http://10.10.10.10/OS/rhel-8.3-x86_64/"
repo --name="AppStream" --baseurl=http://10.10.10.10/OS/rhel-8.3-x86_64/AppStream

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=static --device=enp1s0 --gateway=10.10.10.1 --ip=10.10.10.113 --nameserver=10.10.10.10,10.10.10.42,8.8.8.8 --netmask=255.255.255.0 --ipv6=auto --activate
network  --hostname=rh8-nag-srv01.matrix.lab

# Do not configure the X Window System
skipx
text
reboot
selinux --enforcing
firewall --enabled

# System services
services --disabled="chronyd"
# Intended system purpose
syspurpose --role="Red Hat Enterprise Linux Server" --sla="Standard" --usage="Production"
# System timezone
timezone America/New_York --isUtc 

# User Management
#Root password
rootpw --iscrypted $6$eUp.vIyPAe..7gIU$4H/7/MCo0MRTo1C5H/WVvcprjI2AT6TuiFGt/ixBG/k47aJWP9W7uSpu1hGZBDmNuSNYAdroSsoWB7WHzyfIV.
user --uid=1002 --groups=wheel --name=mansible --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="My Ansible"

# Disk Info
ignoredisk --only-use=vda,vdb
# Partition clearing information
clearpart --none --initlabel
# Partition Info
part /boot --fstype="xfs" --label=boot --ondisk=vda --size=500 
part pv.03 --fstype="lvmpv" --ondisk=vda --size=10240 --grow
#
volgroup vg_rhel8 pv.03
#
logvol /    --fstype=xfs --vgname=vg_rhel8 --name=lv_root --label="root" --size=10240
logvol /home --fstype=xfs --vgname=vg_rhel8 --name=lv_home --label="home" --size=1024
logvol /var --fstype=xfs --vgname=vg_rhel8 --name=lv_var --label="var" --size=8192
logvol /tmp --fstype=xfs --vgname=vg_rhel8 --name=lv_tmp --label="temp" --size=2048

# LibreNMS disk space
part pv.04 --fstype="lvmpv" --ondisk=vdb --size=10240 --grow
volgroup vg_nagios pv.04
logvol /usr/local/nagios --fstype=xfs --vgname=vg_nagios --name=lv_nagios --label="nagios" --size=10240 --grow



%packages
@^server-product-environment
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end

%pre
echo "Kickstart began on: `date`"
%end

%post
echo "Kickstart finished on `date`"
%end
