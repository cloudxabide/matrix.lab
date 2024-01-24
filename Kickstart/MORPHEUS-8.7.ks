#version=RHEL8
# Use Network installation media
url --url=http://10.10.10.10/OS/rhel-8.7-x86_64/
repo --name="AppStream" --baseurl=http://10.10.10.10/OS/rhel-8.7-x86_64/AppStream
# Network information
network  --bootproto=static --device=eno1 --bootproto=dhcp --ipv6=auto --activate
#network  --bootproto=static --device=eno1 --gateway=10.10.10.1 --ip=10.10.10.13 --nameserver=10.10.10.10,10.10.10.42,8.8.8.8 --netmask=255.255.255.0 --ipv6=auto --activate
network  --hostname=morpheus.matrix.lab

# Use graphical install
# graphical
text

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# System timezone
timezone America/New_York --isUtc --nontp
# X Window System configuration information
#xconfig  --startxonboot
# Run the Setup Agent on first boot
#firstboot --enable

# System services
services --enabled="chronyd,cockpit"

# Intended system purpose
syspurpose --role="Red Hat Enterprise Linux Server" --sla="Standard" --usage="Development/Test"
# Root password
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
# User Management
user --uid=1002 --groups=wheel --name=mansible --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="My Ansible"

reboot
eula --agreed

# Disk Management
ignoredisk --only-use=sda,nvme0n1
# Partition clearing information
clearpart --all --initlabel --drives=sda,nvme0n1
# Disk partitioning information
part /boot/efi --fstype="efi" --ondisk=sda --size=600 --fsoptions="umask=0077,shortname=winnt"
part pv.00 --fstype="lvmpv" --ondisk=sda --size=242573
part /boot --fstype="xfs" --ondisk=sda --size=1024

# Volumes
volgroup rhel_vg --pesize=4096 pv.00
logvol /home --fstype="xfs" --grow --size=500 --name=home --vgname=rhel_vg
logvol swap --fstype="swap" --size=24419 --name=swap --vgname=rhel_vg
logvol / --fstype="xfs" --grow --size=1024 --name=root --vgname=rhel_vg

# NVMe device 
part pv.01 --fstype="lvmpv" --ondisk=nvme0n1 --size=10240 --grow
volgroup vg_nvme --pesize=4096 pv.01
logvol /data --fstype="xfs" --size=10240 --grow --name=data --vgname=vg_nvme

%packages
#@^graphical-server-environment
@^minimal-environment
kexec-tools
chrony
cockpit
%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%post --log=/root/ks-post.log
echo "NOTE:  Retrieving Finish Script"
wget http://10.10.10.10/Scripts/post_install.sh -O /root/post_install.sh
sh /root/post_install.sh
%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
