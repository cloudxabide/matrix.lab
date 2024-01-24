# these are things to make ansible'd
echo "blacklist tps6598x" > /etc/modprobe.d/blacklist.conf
modprobe -r tps6598x

# Disable Bluetooth
echo "install bnep /bin/true" >> /etc/modprobe.d/disable-bluetooth.conf
echo "install bluetooth /bin/true" >> /etc/modprobe.d/disable-bluetooth.conf
echo "install hci_usb /bin/true" >> /etc/modprobe.d/disable-bluetooth.conf
systemctl disable bluetooth.service
systemctl mask bluetooth.service
systemctl stop bluetooth.service

# WakeOnLan

SLEEPYTIME=10
MACS="
88:ae:dd:0b:af:9c
1c:69:7a:ab:23:50 
88:ae:dd:0b:90:70"

for MAC in $MACS
do 
  sudo ether-wake $MAC
  sleep $SLEEPYTIME
done

exit 

88:ae:dd:0b:af:9c # morpheus
1c:69:7a:ab:23:50 # neo 
88:ae:dd:0b:90:70 # trinity 
