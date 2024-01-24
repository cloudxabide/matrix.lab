#!/bin/bash

# I *believe* this works, I'll have to test
# Task: Run this script from Github source
# wget -O - https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Scripts/post_install.sh  | sudo bash

WEBSERVER="10.10.10.10"

# Task: update sudo config for mansible
# A new approach to managing sudo for My Ansible (mansible) user
echo "mansible ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/mansible-nopasswd-all
restorecon -RFvv /etc/sudoers.d/mansible-nopasswd-all

# Task: Manage Users
## Determine OS_RELEASE
OS_RELEASE=`grep ^NAME /etc/os-release | awk -F\" '{ print $2 }'`
case $OS_RELEASE in
  "Red Hat Enterprise Linux"|"openSUSE Tumbleweed")
    SECONDARY_GROUP="wheel"
  ;;
  "Ubuntu")
    SECONDARY_GROUP="sudo"
  ;;
  *)
    SECONDARY_GROUP="admin"
  ;;
esac

echo "$SECONDARY_GROUP will be used"
   
## 
## Create User:mansible
id -u mansible &>/dev/null || useradd -m -G${SECONDARY_GROUP} -u1002 -c "My Ansible" -d /home/mansible -s /bin/bash -p '$6$KG59tNcZse1h.baM$qaZadrH8Tajdc6LnBzcmCnIMOnCQxy8tD6mhBq8IdH9cjuWySZ6BSBLXkJl/ypsRqpDtbu95fquBeVp/rP2rb/' mansible
[ ! -f ~mansible/.ssh/id_rsa ] && su - mansible -c "echo | ssh-keygen -trsa -b2048 -N ''"

# Add the SSH Pub Key for lab Ansible User
grep "mansible@rh8-util-srv02.matrix.lab" /home/mansible/.ssh/authorized_keys || { curl https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/mansible%40rh8-util-srv02.matrix.lab >> /home/mansible/.ssh/authorized_keys; }
grep "jradtke@glados" /home/mansible/.ssh/authorized_keys || { curl https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Files/jradtke%40glados >> /home/mansible/.ssh/authorized_keys; }

chown mansible:mansible /home/mansible/.ssh/authorized_keys; chmod 0600 /home/mansible/.ssh/authorized_keys; restorecon -F /home/mansible/.ssh/authorized_keys; 

# Task: enable SSHD (this is "universal" at this point - might need to make this OS-specific)
systemctl enable sshd --now
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# Task: Install Ansible
case $OS_RELEASE in
  "openSUSE Tumbleweed")
    sudo zypper refresh
    sudo zypper install ansible
    sudo zypper info ansible
    ansible --version
  ;;
esac

exit 0

# Update DNS (not sure why kickstart no longer handles this.  Ugh...
# NOTE: This next bit WILL fail at some point - Interfaces sometimes have spaces - like "System Eth0" - why did this change??? UGH
#MYCONN=$(nmcli conn show | grep -v ^NAME | awk '{ print $1 }')
#$(grep 10.10.10.121  /etc/resolv.conf)  || { nmcli conn modify "$MYCONN" ipv4.ignore-auto-dns yes; nmcli conn modify "$MYCONN" ipv4.dns "10.10.10.122 10.10.10.121 8.8.4.4"; systemctl restart NetworkManager; }
