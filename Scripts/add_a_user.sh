#!/bin/bash

#  STATUS:  Work In Progress
# PURPOSE:  add a user to my ENV
#   NOTES:  Update {PLAIN,ENC}PASS

[ $# -ne 2 ] && { echo "Error: $0 <user> <encrypted_pass>"; exit 9; }
USER=${1}
ENCPASS="${2}"
ENCPASS="$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/\""

useradd -p $ENCPASS -c "Lab User" ${1} 
usermod -a -G wheel ${1}
su - $USER -c "echo | ssh-keygen -trsa -b2048 -N ''"
su - $USER -c "cat .ssh/id_rsa.pub > .ssh/authorized_keys"
su - $USER -c "chmod 0600 .ssh/authorized_keys"


# Or...
# useradd -m USER && echo "USER:PASSWORD" | chpasswd

# If you have a bunch of home dirs (but no matching users), run this...
# ls -l | awk '{ print "useradd -p \"$6$03gqrB.BA2aR.mkG$gSzJgslhseoNAe1GojYe8uQG1/mavSGIVf62BDA9MtQkRr06Ua9AXYspTOsdJ61d1QUmEhojWQ7RG.oZeWyu9/\" -c \"Lab User\" -u " $3 " "$9 }'
