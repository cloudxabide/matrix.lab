#version=RHEL8
# License agreement
eula --agreed
# Reboot after installation
reboot
# Use graphical install
graphical

repo --name="AppStream" --baseurl=http://10.10.10.10/OS/rhel-8.5-x86_64/AppStream

%packages
@^minimal-environment
kexec-tools
kexec-tools

%end

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=static --device=eno1 --gateway=10.10.10.1 --ip=10.10.10.42 --nameserver=10.10.10.10,10.10.10.42,8.8.8.8 --netmask=255.255.255.0 --ipv6=auto --activate
network  --hostname=sati.matrix.lab

# Use network installation
url --url="http://10.10.10.10/OS/rhel-8.5-x86_64/"

# X Window System configuration information
xconfig  --startxonboot
# Run the Setup Agent on first boot
firstboot --enable
# System services
services --disabled="chronyd"

ignoredisk --only-use=sda
# Partition clearing information
clearpart --all --initlabel --drives=sda
# Disk partitioning information
part pv.328 --fstype="lvmpv" --ondisk=sda --size=242573
part /boot --fstype="xfs" --ondisk=sda --size=1024
part /boot/efi --fstype="efi" --ondisk=sda --size=600 --fsoptions="defaults,uid=0,gid=0,umask=077,shortname=winnt"
volgroup rhel_sati --pesize=4096 pv.328
logvol / --fstype="xfs" --grow --size=1024 --name=root --vgname=rhel_sati
logvol swap --fstype="swap" --size=24419 --name=swap --vgname=rhel_sati
logvol /home --fstype="xfs" --grow --size=500 --name=home --vgname=rhel_sati

# Intended system purpose
syspurpose --role="Red Hat Enterprise Linux Server" --sla="Standard" --usage="Development/Test"

# System timezone
timezone America/New_York --isUtc --nontp

# Root password
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
user --groups=wheel --name=mansible --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --uid=1002 --gecos="My Ansible"

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
