#version=RHEL8
ignoredisk --only-use=vda
autopart --type=lvm
# Partition clearing information
clearpart --none --initlabel
# Use graphical install
text

# Use Network installation media
url --url=http://10.10.10.10/OS/rhel-8.5-x86_64/
repo --name="AppStream" --baseurl=http://10.10.10.10/OS/rhel-8.5-x86_64/AppStream

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=static --device=ens192 --gateway=10.10.10.1 --ip=10.10.10.121 --nameserver=10.10.10.10,10.10.10.42,8.8.8.8 --netmask=255.255.255.0 --ipv6=auto --activate
network  --hostname=rh8-idm-srv01.matrix.lab

# Root password
rootpw --iscrypted $6$eUp.vIyPAe..7gIU$4H/7/MCo0MRTo1C5H/WVvcprjI2AT6TuiFGt/ixBG/k47aJWP9W7uSpu1hGZBDmNuSNYAdroSsoWB7WHzyfIV.
# Run the Setup Agent on first boot
firstboot --enable
# Do not configure the X Window System
skipx
# System services
services --disabled="chronyd"
# Intended system purpose
syspurpose --role="Red Hat Enterprise Linux Server" --sla="Standard" --usage="Production"
# System timezone
timezone America/New_York --isUtc --nontp
user --uid=1002 --groups=wheel --name=mansible --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="My Ansible"

%packages
@^minimal-environment
#@^server-product-environment
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
