#version=RHEL8
# Use graphical install
#graphical

# Use Network installation media
url --url=http://10.10.10.10/OS/rhel-8.5-x86_64/
repo --name="AppStream" --baseurl=http://10.10.10.10/OS/rhel-8.5-x86_64/AppStream

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=static --device=eno1 --gateway=10.10.10.1 --ip=10.10.10.42 --nameserver=10.10.10.10,10.10.10.42,8.8.8.8 --netmask=255.255.255.0 --ipv6=auto --activate
network  --hostname=sati.matrix.lab
# Root password
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
# X Window System configuration information
xconfig  --startxonboot
# Run the Setup Agent on first boot
firstboot --enable
# System services
services --disabled="chronyd"
# Intended system purpose
syspurpose --role="Red Hat Enterprise Linux Server" --sla="Standard" --usage="Development/Test"
# System timezone
timezone America/New_York --isUtc --nontp
user --uid=1002 --groups=wheel --name=mansible --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="My Ansible"

reboot
eula --agreed

# Disk Management
ignoredisk --only-use=sda
# Partition clearing information
clearpart --all --initlabel --drives=sda
# Disk partitioning information
part /boot/efi --fstype="efi" --ondisk=sda --size=600 --fsoptions="umask=0077,shortname=winnt"
part pv.436 --fstype="lvmpv" --ondisk=sda --size=242573
part /boot --fstype="xfs" --ondisk=sda --size=1024
# Volumes
volgroup rhel_sati --pesize=4096 pv.436
logvol /home --fstype="xfs" --grow --size=500 --name=home --vgname=rhel_sati
logvol swap --fstype="swap" --size=24419 --name=swap --vgname=rhel_sati
logvol / --fstype="xfs" --grow --size=1024 --name=root --vgname=rhel_sati

%packages
@^minimal-environment
kexec-tools
%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
