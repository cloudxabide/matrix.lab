#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
cmdline
# Use network installation
url --url="http://10.10.10.10/OS/rhel-server-7.9-x86_64/"
# Run the Setup Agent on first boot
#firstboot --enable
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network --bootproto=static --device=eth0 --ip=10.10.10.42 --netmask=255.255.255.0 --gateway=10.10.10.1 --activate --nameserver=10.10.10.10,10.10.10.42 --hostname=sati.matrix.lab 

# Root password
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
user --uid=1002 --groups=wheel --name=mansible --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="My Ansible"

# System timezone
timezone America/New_York --isUtc --ntpservers=0.rhel.pool.ntp.org,1.rhel.pool.ntp.org,2.rhel.pool.ntp.org,3.rhel.pool.ntp.org

#########################################################################
### DISK ###
# System bootloader configuration
bootloader --location=mbr --boot-drive=vda 
# Disk Management
ignoredisk --only-use=sda
# Partition clearing information
clearpart --all --initlabel --drives=sda

# Disk partitioning information
part /boot/efi --fstype="efi" --ondisk=sda --size=600 --fsoptions="umask=0077,shortname=winnt"
part pv.03 --fstype="lvmpv" --ondisk=sda --size=20480 --grow
part /boot --fstype="xfs" --ondisk=sda --size=1024
#
volgroup vg_rhel7 pv.03
#
logvol /    --fstype=xfs --vgname=vg_rhel7 --name=lv_root --label="root" --size=10240
logvol /home --fstype=xfs --vgname=vg_rhel7 --name=lv_home --label="home" --size=1024
logvol /var --fstype=xfs --vgname=vg_rhel7 --name=lv_var --label="var" --size=8192
logvol /tmp --fstype=xfs --vgname=vg_rhel7 --name=lv_tmp --label="temp" --size=2048

eula --agreed
reboot

%packages
@base
@core
expect
dracut-fips
ntp
tuned
%end

%post --log=/root/ks-post.log
wget http://10.10.10.10/Scripts/post_install.sh -O /root/post_install.sh
%end

