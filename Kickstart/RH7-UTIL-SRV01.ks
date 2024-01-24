#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
cmdline
# Run the Setup Agent on first boot
#firstboot --enable
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

url --url="http://10.10.10.10/OS/rhel-server-7.9-x86_64/"

# Network information
network --bootproto=static --device=eth0 --gateway=10.10.10.1 --ip=10.10.10.101 --netmask=255.255.255.0 --activate --nameserver=10.10.10.122,10.10.10.121,8.8.8.8 --hostname=rh7-util-srv01.matrix.lab 

# Root password
rootpw --iscrypted $6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/
user --uid=1002 --groups=wheel --name=mansible --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="My Ansible"

# System timezone
timezone America/New_York --isUtc --ntpservers=zion.matrix.lab,apoc.matrix.lab,sati.matrix.lab

#########################################################################
### DISK ###
# System bootloader configuration
bootloader --location=mbr --boot-drive=sda
ignoredisk --only-use=sda

# Partition clearing information
zerombr
clearpart --all --initlabel --drives=sda

# Partition Info
part /boot --fstype="xfs" --ondisk=sda --size=500
part /boot/efi --fstype="efi" --ondisk=sda --size=600 --fsoptions="defaults,uid=0,gid=0,umask=077,shortname=winnt"
part pv.03 --fstype="lvmpv" --ondisk=sda --size=10240 --grow
#
volgroup vg_rhel pv.03
#
logvol /              --fstype=xfs   --vgname=vg_rhel  --name=lv_root  --label="root"  --size=10240
logvol swap           --fstype=swap  --vgname=vg_rhel  --name=lv_swap  --label="swap"  --size=2048
logvol /home          --fstype=xfs   --vgname=vg_rhel  --name=lv_home  --label="home"  --size=1024
logvol /tmp           --fstype=xfs   --vgname=vg_rhel  --name=lv_tmp   --label="temp"  --size=1024
logvol /var           --fstype="xfs" --vgname=vg_rhel  --name=var      --label="var"   --size=8192
logvol /var/log       --fstype="xfs" --vgname=vg_rhel  --name=varlog   --label="log"   --size=8192  
logvol /var/log/audit --fstype="xfs" --vgname=vg_rhel  --name=varaudit --label="audit" --size=2048  

eula --agreed
reboot

%packages
@base
@core
ntp
perl
yum-plugin-downloadonly
tuned
deltarpm
%end

%post --log=/root/ks-post.log
wget http://10.10.10.10/Scripts/post_install.sh -O /root/post_install.sh
%end

