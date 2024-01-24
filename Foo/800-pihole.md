mem: 2048
cpu: 2
Install: min


# echo "mansible ALL=(ALL)	NOPASSWD: ALL" | sudo tee -a /etc/sudoers.d/mansible 

# I find their lack of f̶a̶i̶t̶h̶ SELinux disturbing... ugh.
sudo sed -i -e 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config

sudo su -

firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload

PKGS="git "
dnf -y install $PKGS
dnf -y update && shutdown now -r


git clone --depth 1 https://github.com/pi-hole/pi-hole.git Pi-hole
cd "Pi-hole/automated install/"
sudo bash basic-install.sh

echo "server=/evil.corp/192.168.0.4" > /etc/dnsmasq.d/10-evilcorp.conf
echo "server=/evil.corp/192.168.0.5" >> /etc/dnsmasq.d/10-evilcorp.conf
pihole restartdns
