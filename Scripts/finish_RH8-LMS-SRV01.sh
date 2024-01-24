#!/bin/bash

subscription-manager register --auto-attach
insights-client --register
systemctl enable --now cockpit.socket 

subscription-manager repos --disable="*" --enable=rhel-8-for-x86_64-baseos-rpms --enable=rhel-8-for-x86_64-supplementary-rpms --enable=rhel-8-for-x86_64-appstream-rpms --enable "codeready-builder-for-rhel-8-$(arch)-rpms"
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

yum -y install git

# https://docs.librenms.org/Installation/Install-LibreNMS/
dnf -y install epel-release
dnf -y module reset php
dnf -y module enable php:7.3
dnf -y install bash-completion cronie fping git httpd ImageMagick mariadb-server mtr net-snmp net-snmp-utils nmap php-fpm php-cli php-common php-curl php-gd php-json php-mbstring php-process php-snmp php-xml php-zip php-mysqlnd python3 python3-PyMySQL python3-redis python3-memcached python3-pip python3-systemd rrdtool unzip
dnf -y install gcc python3-devel

useradd librenms -d /opt/librenms -M -r -s "$(which bash)"
cd /opt
git clone https://github.com/librenms/librenms.git
chown -R librenms:librenms /opt/librenms
chmod 771 /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/


su - librenms
./scripts/composer_wrapper.php install --no-dev
exit

sed -i -e 's/mariadb.pid/mariadb.pid\ninnodb_file_per_table=1\nlower_case_table_names=0/g' /etc/my.cnf.d/mariadb-server.cnf
systemctl enable --now mariadb

mysql --host localhost --user root  << END

CREATE DATABASE librenms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'librenms'@'localhost' IDENTIFIED BY 'NotAPassword';
GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'localhost';
FLUSH PRIVILEGES;
exit
END

cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/librenms.conf
cp /etc/php-fpm.d/librenms.conf  /etc/php-fpm.d/.-librenms.conf
sed -i -e 's/\[www]/\[librenms]/g' /etc/php-fpm.d/librenms.conf
sed -i -e 's/user\ =\ apache/user = librenms/g' /etc/php-fpm.d/librenms.conf
sed -i -e 's/group\ =\ apache/group = librenms/g' /etc/php-fpm.d/librenms.conf
sed -i -e 's/listen\ =\ \/run\/php-fpm\/www.sock/listen\ =\ \/run\/php-fpm-librenms.sock/g' /etc/php-fpm.d/librenms.conf
sed -i -e 's/listen\ =\ \/run\/php-fpm\/www.sock/listen = \/run\/php-fpm-librenms.sock/g' /etc/php-fpm.d/librenms.conf

sdiff /etc/php-fpm.d/librenms.conf  /etc/php-fpm.d/.-librenms.conf | grep \|

cat << EOF > /etc/httpd/conf.d/librenms.conf
<VirtualHost *:80>
  DocumentRoot /opt/librenms/html/
  ServerName  librenms.matrix.lab

  AllowEncodedSlashes NoDecode
  <Directory "/opt/librenms/html/">
    Require all granted
    AllowOverride All
    Options FollowSymLinks MultiViews
  </Directory>

  # Enable http authorization headers
  <IfModule setenvif_module>
    SetEnvIfNoCase ^Authorization$ "(.+)" HTTP_AUTHORIZATION=$1
  </IfModule>

  <FilesMatch ".+\.php$">
    SetHandler "proxy:unix:/run/php-fpm-librenms.sock|fcgi://localhost"
  </FilesMatch>
</VirtualHost>
EOF

mv /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/.welcome.conf.bak

systemctl enable --now httpd
systemctl enable --now php-fpm 

dnf -y install policycoreutils-python-utils

semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/html(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/(logs|rrd|storage)(/.*)?'
semanage fcontext -a -t bin_t '/opt/librenms/librenms-service.py'
restorecon -RFvv /opt/librenms
setsebool -P httpd_can_sendmail=1
setsebool -P httpd_execmem 1
chcon -t httpd_sys_rw_content_t /opt/librenms/.env

cat << EOF > http_fping.tt
module http_fping 1.0;

require {
type httpd_t;
class capability net_raw;
class rawip_socket { getopt create setopt write read };
}

#============= httpd_t ==============
allow httpd_t self:capability net_raw;
allow httpd_t self:rawip_socket { getopt create setopt write read };
EOF

checkmodule -M -m -o http_fping.mod http_fping.tt
semodule_package -o http_fping.pp -m http_fping.mod
semodule -i http_fping.pp

audit2why < /var/log/audit/audit.log

firewall-cmd --zone public --add-service http --add-service https
firewall-cmd --permanent --zone public --add-service http --add-service https

ln -s /opt/librenms/lnms /usr/bin/lnms
cp /opt/librenms/misc/lnms-completion.bash /etc/bash_completion.d/

cp /opt/librenms/snmpd.conf.example /etc/snmp/snmpd.conf
sed -i -e 's/RANDOMSTRINGGOESHERE/publicRO/g' /etc/snmp/snmpd.conf

cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms
cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms
chown librenms:librenms /opt/librenms/config.php
sed -i -e 's/;date.timezone =/;date.timezone =\ndate.timezone = \"America\/New_York\"/g' /etc/php.ini
sed -i -e 's/#DB_HOST=/DB_HOST=localhost/g' /opt/librenms/.env
sed -i -e 's/#DB_DATABASE=/DB_DATABASE=librenms/g' /opt/librenms/.env
sed -i -e 's/#DB_USERNAME=/DB_USERNAME=librenms/g' /opt/librenms/.env
sed -i -e 's/#DB_PASSWORD=/DB_PASSWORD=NotAPassword/g' /opt/librenms/.env

# Dump the existing IP -> Host entries (in case DNS is unavailable)
host -l matrix.lab  | awk '{ print $4" " $1 }'  | sort -t . -k1,1n -k2,2n -k3,3n -k4,4n  >> /etc/hosts

su - librenms
./validate.php
# IF it fails
# mysql -u librenms -p librenms
# SET TIME_ZONE='+00:00';
# ALTER TABLE `notifications` CHANGE `datetime` `datetime` timestamp NOT NULL DEFAULT '1970-01-02 00:00:00' ;
# ALTER TABLE `users` CHANGE `created_at` `created_at` timestamp NOT NULL DEFAULT '1970-01-02 00:00:01' ; 
for HOST in apoc tank dozer seraph cisco-sg300-28
do
  ./addhost.php  ${HOST} publicRO v2c; 
done
exit

# 
setsebool -P httpd_run_stickshift 1
setsebool -P httpd_setrlimit 1

setsebool -P httpd_can_network_connect 1
setsebool -P httpd_graceful_shutdown 1
setsebool -P httpd_can_network_relay 1
setsebool -P nis_enabled 1
