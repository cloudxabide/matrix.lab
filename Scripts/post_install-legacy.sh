#!/bin/bash

export SATADMINPASSWD="NotAPassword"

[ `id` -ne 0 ] && { echo "ERROR: you should run this as root yo"; exit 9 }

#set -o errexit
readonly LOG_FILE="/root/post_install.sh.log"
echo "Output being redirected to log file - to see output:"
echo "tail -f $LOG_FILE"

# Simple test/check to see if script is still running, or has been run already
ps -ef | grep post_instaill.sh | grep -v grep && { echo "ERROR: script is already running"; exit 9; }
[ -f $LOG_FILE ] && { echo "Log File exists.  Remove log if you *really* want to run this script"; exit 9; }

touch $LOG_FILE
exec 1>$LOG_FILE 
exec 2>&1 

WEBSERVER="10.10.10.10"
PWD=`pwd`
DATE=`date +%Y%m%d`
ARCH=`uname -p`
YUM=$(which yum)

echo "# NOTE: Running post_install.sh at `date +%F`"

if [ `/bin/whoami` != "root" ]
then
  echo "ERROR:  You should be root to run this..."
  exit 9
fi

# Grab the finish_script (if available)
case `hostname -s` in 
  rh7*|rh8*) FINHOSTNAME=$(hostname -s | tr [a-z] [A-Z]);;
  *) FINHOSTNAME=$(hostname -s);;
esac
wget http://${WEBSERVER}/Scripts/finish_${FINHOSTNAME}.sh

# Display warning (in case this script was run interactively)
SLEEPYTIME=5
echo "NOTE: This script will update host and REBOOT host"
echo "  Press CTRL-C to quit (you have ${SLEEPYTIME} seconds)"
while [ $SLEEPYTIME -gt 0 ]; do echo -ne "Will proceed in:  $SLEEPYTIME\033[0K\r"; sleep 1; : $((SLEEPYTIME--)); done

# FUTURE:  need to make sure fips=1 is in the grub:cmdline if enabled

# Determine whether we are using Satellite or RHN and update the subscription, if needed
CAPSHOSTNAME=`hostname -s | tr [a-z] [A-Z]`
# WEBSERVER=10.10.10.10; USE_SATELLITE=1
USE_SATELLITE=`curl -s ${WEBSERVER}/Scripts/.myconfig | grep -w $CAPSHOSTNAME | awk -F: '{ print $12 }'`
ENVIRONMENTALS="${HOME}/environmentals.txt"
curl -s ${WEBSERVER}/Scripts/environmentals.txt > $ENVIRONMENTALS && . ${ENVIRONMENTALS}
[ -z $USE_SATELLITE ] && USE_SATELLITE=1

case `hostname -s` in
  neo|trinity|morpheus) ACTIVATIONKEY="ak-rhel7-library-infra";;
  apoc|zion) ACTIVATIONKEY="ak-rhel8-library-infra";;
  *ocp3*) ACTIVATIONKEY="ak-ocp3";;
esac

case $USE_SATELLITE in
  0)
    export rhnuser=$(curl -s ${WEBSERVER}/OS/.rhninfo | grep rhnuser | cut -f2 -d\=)
    export rhnpass=$(curl -s ${WEBSERVER}/OS/.rhninfo | grep rhnpass | cut -f2 -d\=)
    [ ! -e $rhnuser ] && subscription-manager status || subscription-manager register --auto-attach --force --username="${rhnuser}" --password="${rhnpass}"
  ;;
  *)
    # THIS ABSOLUTELY NEEDS CLEANUP (I'll deal with this later)
    yum clean all; subscription-manager clean
    curl --insecure --output katello-ca-consumer-latest.noarch.rpm https://${SATELLITE}.${DOMAIN}/pub/katello-ca-consumer-latest.noarch.rpm
    yum -y localinstall katello-ca-consumer-latest.noarch.rpm
    # I temp created this registration method (2019-12)
    subscription-manager register --org="${ORGANIZATION}"  --environment="Library" --username='satadmin' --password="$SATADMINPASSWD" --auto-attach --force
    #subscription-manager register --org="${ORGANIZATION}" --activationkey="$ACTIVATIONKEY" --force
  ;;
esac

# Repo/Channel Management
# subscription-manager facts --list  | grep distribution.version: | awk '{ print $2 }' <<== Alternate to gather "version"
case `cut -f5 -d\: /etc/system-release-cpe` in
  7.*)
    echo "NOTE:  detected EL7"
    [ $USE_SATELLITE == 1 ] && EXTRAS="--enable rhel-7-server-satellite-tools-6.9-rpms --enable=rhel-8-for-x86_64-appstream-rpms"
    # Temp - set the release
    #subscription-manager release --set=7.7
    subscription-manager repos --disable="*" --enable rhel-7-server-rpms $EXTRAS
  ;;
  8.*)
    echo "NOTE:  detected EL8"
    [ $USE_SATELLITE == 1 ] && EXTRAS="--enable satellite-tools-6.7-for-rhel-8-x86_64-rpms"
    subscription-manager repos --disable="*" --enable=rhel-8-for-x86_64-baseos-rpms $EXTRAS
  ;;
esac

# If we are using Satellite, add katello
[ $USE_SATELLITE == 1 ] && { yum -y install katello-agent; katello-package-upload; }

#########################
## USER MANAGEMENT
#########################
# Create an SSH key/pair if one does not exist (which should be the case for a new system)
[ ! -f /root/.ssh/id_rsa ] && echo | ssh-keygen -trsa -b2048 -N ''

# Add a local Docker group
groupadd -g 1001 docker 

# Add local group/user for Ansible and allow sudo NOPASSWD: ALL
id -u mansible &>/dev/null || useradd -Gwheel -u1002 -c "My Ansible" -p '$6$MIxbq9WNh2oCmaqT$10PxCiJVStBELFM.AKTV3RqRUmqGryrpIStH5wl6YNpAtaQw.Nc/lkk0FT9RdnKlEJEuB81af6GWoBnPFKqIh.' mansible
su - mansible -c "echo | ssh-keygen -trsa -b2048 -N ''" 
cat << EOF > /etc/sudoers.d/01-myansble

# Allow the group 'mansible' to run sudo (ALL) with NOPASSWD
%mansible 	ALL=(ALL)	NOPASSWD: ALL
EOF

# Setup wheel group for NOPASSWD: (only for a non-production ENV)
sed -i -e 's/^%wheel/#%wheel/g' /etc/sudoers
sed --in-place 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers

#########################
## MONITORING AND SYSTEM MANAGEMENT
#########################
# Install deltarpm to (hopefully) minimize the bandwith
yum -y install deltarpm

# Enable Cockpit (AFAIK this will be universally applied)
# Manage Cockpit
yum -y install cockpit
systemctl enable cockpit.socket --now
firewall-cmd --permanent --zone=$(firewall-cmd --get-default-zone) --add-service=cockpit 
firewall-cmd --complete-reload

# Enable Repo for SNMP pkgs (might move this higher up in the script
case `cut -f5 -d\: /etc/system-release-cpe` in
  8*)
    echo "NOTE:  detected EL8"
    subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms
    yum -y install  net-snmp-libs
  ;;
esac

# Enable SNMP (for LibreNMS)
yum -y install  net-snmp net-snmp-utils
mv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf-`date +%F`
WEBSERVER=10.10.10.10
curl http://${WEBSERVER}/Files/etc_snmp_snmpd.conf > /etc/snmp/snmpd.conf
restorecon -Fvv /etc/snmp/snmpd.conf
systemctl enable snmpd --now 

firewall-cmd --permanent --add-service=snmp
firewall-cmd --reload

case `lsb_release  -d` in 
  'Ubuntu 18.04.5 LTS')
    echo "agentAddress udp:0.0.0.0:161" >> /etc/snmp/snmpd.conf
  ;;
esac

# Install Sysstat (SAR) and PCP
yum -y install sysstat pcp
systemctl enable sysstat --now

#  Configure Parameters (tuned, repos) based on hardware type 
$(which yum) -y install tuned
case `dmidecode -s system-manufacturer` in
  'Red Hat'|'oVirt')
    tuned-adm profile virtual-guest
    subscription-manager repos --enable=rhel-7-server-rh-common-rpms
    yum -y install rhevm-guest-agent
    systemctl enable ovirt-guest-agent; systemctl start $_
  ;;
  HP)
    tuned-adm profile virtual-host
  ;;
  *)
    tuned-adm profile balanced
  ;;
esac 

# THIS IS A TEMP THING AND I'LL work it in to kickstart
#syspurpose set role "Red Hat Enterprise Linux Server"; sleep 5
#syspurpose set usage "Development/Test"
#syspurpose set role ""; sleep 5
#syspurpose set usage ""

subscription-manager syspurpose role --set="Red Hat Enterprise Linux Server"
subscription-manager syspurpose usage --set="Development/Test" 
subscription-manager syspurpose service-level --set="Self-Support"
subscription-manager status

which insights-client || yum -y install insights-client
insights-client --register --group MATRIXLAB

#  Update Host and reboot
echo "NOTE:  update and reboot"
yum -y update && shutdown now -r

exit  0

