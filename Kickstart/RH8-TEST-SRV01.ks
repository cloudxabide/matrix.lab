#version=RHEL8
ignoredisk --only-use=sda
autopart --type=lvm
# Partition clearing information
clearpart --none --initlabel
# Do NOT Use graphical install
text

# Use the Network Installation
url --url="http://10.10.10.10/OS/rhel-8.5-x86_64/"
repo --name="AppStream" --baseurl=http://10.10.10.10/OS/rhel-8.5-x86_64/AppStream

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
#network  --bootproto=static --device=enp1s0 --gateway=10.10.10.1 --ip=10.10.10.114 --nameserver=10.10.10.10,10.10.10.42,8.8.8.8 --netmask=255.255.255.0 --ipv6=auto --activate
network  --bootproto=dhcp --device=ens192 --ipv6=auto --activate
network  --hostname=rh8-test-srv01.matrix.lab

# Root password
rootpw --iscrypted $6$gmJsij7ehBWB2aRd$t7BLPrLryxRNWaLQaTm5K3HlPJx9.3VkdL8hTGnsPrIoWil5mwJoZqwnUin.5vzCFI53MOebzXQzWmk/kWO.61
# Run the Setup Agent on first boot
skipx
# System services
services --disabled="chronyd"

# Intended system purpose
#syspurpose --role="Red Hat Enterprise Linux Server" --sla="Standard" --usage="Production"
#syspurpose --role="Red Hat Enterprise Linux Server" --service_level_agreement="Standard" --usage="Production"

# System timezone
timezone America/New_York --isUtc --nontp
user --uid=1002 --groups=wheel --name=mansible --password=$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/ --iscrypted --gecos="My Ansible"
reboot

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

%post --erroronfail --log=/root/ks-post.log
echo "" | ssh-keygen -trsa -b2048 -N ''
curl -o /root/.ssh/authorized_keys http://10.10.10.10/Files/authorized_keys
chmod 0600 /root/.ssh/authorized_keys

su - mansible -c "echo | ssh-keygen -trsa -b2048 -N '' "
curl -o /home/mansible/.ssh/authorized_keys http://10.10.10.10/Files/authorized_keys
chown mansible:mansible /home/mansible/.ssh/authorized_keys 
restorecon -RF /home/mansible/.ssh/
chmod 0600 /home/mansible/.ssh/authorized_keys
%end


