#!/bin/bash
USERS="mansible jradtke"
for USER in $USERS
do
  echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER
done

apt update
apt -y install snmpd snmp libsnmp-dev
echo "rocommunity publicRO 10.10.10.110" > /etc/snmp/snmpd.conf.d/localhost.conf

LINENUM=$(grep -n ^agentaddress /etc/snmp/snmpd.conf | cut -f1 -d\:)
sed -i -e 's/^agentaddress/#agentaddress/g' /etc/snmp/snmpd.conf
MYIP=$(hostname -I | sed 's/172.17.0.1//g' | sed 's/ //g')
sed -i -e "${LINENUM}iagentaddress udp:127.0.0.1:161,udp:${MYIP}:161" /etc/snmp/snmpd.conf
grep agentaddress /etc/snmp/snmpd.conf 
systemctl enable snmpd --now
ufw allow from 10.10.10.110 to any port 161 proto udp comment "Allow SNMP Scan from Monitoring Server"

apt -y install powertop
systemctl enable powertop.service --now

DISABLE_SERVICES=""

for SVC in $DISABLE_SERVICES
do 
  systemctl disable $SVC --now
done

# No clue... but this driver will consume an entire CPU core :-(
modprobe -r tps6598x


