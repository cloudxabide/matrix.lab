#!/bin/bash
# Author: William Lam
# Blog: www.virtuallyghetto.com
# Description: Script to import vCenter Server 6.x root certificate to Mac OS X or NIX* system
# Reference: http://www.virtuallyghetto.com/2016/07/automating-the-import-of-vcenter-server-6-x-root-certificate.html

# NOTE:  !! - THIS IS/WAS NOT MY SCRIPT - !!
#             CREDIT GOES TO WILLIAM LAM 
#             HOWEVER, I NEEDED TO TWEAK IT TO GET IT TO WORK (and I am not ready to do a PR for the changes)

# ensure root user is running the script
if [ "$(id -u)" != "0" ]; then
  echo -e "Please run this script using sudo\n"
  exit 1
fi

# Check for correct number of arguments
if [ ${#} -ne 1 ]; then
  echo "Usage: \n\t$0 [VC_HOSTNAME]\n"
  exit 1
fi

NODE_IP=$1

# Automatically determine if OS type is Mac OS X or NIX*
if [ $(uname -s) == "Darwin" ]; then
  OS_TYPE=OSX
fi

# Automatically determine if node is a VC or ESXi endpoint
curl --connect-timeout 10 -k -s "https://${NODE_IP}" | grep 'forAdmins' > /dev/null 2>&1
if [ $? -eq 0 ]; then
    NODE_TYPE=vcenter
else
    NODE_TYPE=esxi
fi
echo "Environment Type: $NODE_TYPE"

DOWNLOAD_PATH=/tmp/cert.zip
if [ "${NODE_TYPE}" == "vcenter" ]; then
  # Determine if VC is Windows VC or VCSA by checking VAMI endpoint
  if [ $(curl --connect-timeout 10 -s -o /dev/null -w "%{http_code}" -i -k https://${NODE_IP}:5480) -eq 200 ]; then
    # Install Trusted root CA for vCenter Server Appliance
    echo "\nDownloading VC SSL Certificate to ${DOWNLOAD_PATH}"
    #- # Check to see if the URL is the old filename or the new
    #- HTTP_CODE=$(curl -k -s -w "%{http_code}" "https://${NODE_IP}/certs/download" -o ${DOWNLOAD_PATH})
    #- if [ "${HTTP_CODE}" -eq 400 ]; then
    #-    curl -k -s "https://${NODE_IP}/certs/download.zip" -o ${DOWNLOAD_PATH}
    #- fi
    echo "#CMD  curl -k -s \"https://${NODE_IP}/certs/download.zip\" -o ${DOWNLOAD_PATH} "
    curl -k -s "https://${NODE_IP}/certs/download.zip" -o ${DOWNLOAD_PATH}
    unzip ${DOWNLOAD_PATH} -d /tmp > /dev/null 2>&1
    for i in $(ls /tmp/certs/mac/*.0);
    do
      SOURCE_CERT=${i%%.*}
      echo "#CMD: cp \"${i}\" \"/tmp/certs/mac/${SOURCE_CERT##*/}.crt\" "
      cp "${i}" "/tmp/certs/mac/${SOURCE_CERT##*/}.crt"
      echo "Importing to VC SSL Certificate to Certificate Store"
      if [ "${OS_TYPE}" == "OSX" ]; then
        echo "# sudo security authorizationdb write com.apple.trust-settings.admin allow"
        sudo security authorizationdb write com.apple.trust-settings.admin allow
        echo "# security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain \"/tmp/certs/mac/${SOURCE_CERT##*/}.crt\" "
        security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "/tmp/certs/mac/${SOURCE_CERT##*/}.crt"
      else
        echo "# cp \"${i}\" \"/usr/local/share/ca-certificates/${SOURCE_CERT##*/}.crt\" "
        #cp "${i}" "/usr/local/share/ca-certificates/${SOURCE_CERT##*/}.crt"
      fi
    done
  else
    # Install Trusted root CA for vCenter Server for Windows
    echo -e "\nDownloading VC SSL Certificate to ${DOWNLOAD_PATH}"
    curl -k -s "https://${NODE_IP}/certs/download.zip" -o ${DOWNLOAD_PATH}
    unzip ${DOWNLOAD_PATH} -d /tmp > /dev/null 2>&1
    for i in $(ls /tmp/certs/mac/*.0);
    do
      SOURCE_CERT=${i%%.*}
      echo "cp \"${i}\" \"/tmp/certs/${SOURCE_CERT##*/}.crt\" "
      cp "${i}" "/tmp/certs/${SOURCE_CERT##*/}.crt"
      echo "Importing to VC SSL Certificate to Certificate Store"
      if [ "${OS_TYPE}" == "OSX" ]; then
        echo "security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain \"/tmp/certs/${SOURCE_CERT##*/}.crt\" "
        security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "/tmp/certs/${SOURCE_CERT##*/}.crt"
      else
        echo "# cp /tmp/certs/mac/*.0 /usr/local/share/ca-certificates/*.crt"
        cp /tmp/certs/mac/*.0 /usr/local/share/ca-certificates/*.crt
        echo "# update-ca-certificates"
        update-ca-certificates
      fi
    done
  fi
elif [ "${NODE_TYPE}" == "esxi" ]; then
  # Install Trusted root CA for ESXi
  echo -n | openssl s_client -showcerts -connect "${NODE_IP}":443 2>/dev/null | openssl x509 > /tmp/certs/esxi_cert.crt
  echo "Importing to VC SSL Certificate to Certificate Store"
  if [ "${OS_TYPE}" == "OSX" ]; then
    echo "# security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain \"/tmp/certs/esxi_cert.crt\" "
    security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "/tmp/certs/esxi_cert.crt"
  else
    echo "# cp /tmp/esxi_cert.crt /usr/local/share/ca-certificates"
    cp /tmp/esxi_cert.crt /usr/local/share/ca-certificates
    update-ca-certificates
  fi
fi

echo "# Cleaning up, delete /tmp/cert.zip"
#rm -rf /tmp/cert.zip
echo "# Cleaning up, delete /tmp/certs"
#rm -rf /tmp/certs
exit 0
