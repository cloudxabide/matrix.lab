#!/bin/bash

# STATUS:  This still needs to some logic checking and error handling
# PURPOSE:  To change the UID/GID of a user and update all of their files

USER="mansible"
NEW_UID=1002
NEW_GID=1002

[ `id -u $USER` ] || { echo "FAILED: user $USER does not exist. Run post_install.sh"; exit 9; }

ORIG_UID=$(id -u $USER)
ORIG_GID=$(id -g $USER)

# Need to create an exit if the UID already matches too here....

echo "Changing UID (from/to):  $ORIG_UID / $NEW_UID"
echo "Changing GID (from/to):  $ORIG_GID / $NEW_GID"

usermod -u $NEW_UID $USER || { echo "FAILED"; exit 9; }
groupmod -g $NEW_GID $USER || { echo "FAILED"; exit 9; }

# Notice the first "find" searches on GID - I think the usermod most update the home dir?
find /home/ -group $ORIG_GID -exec chgrp $USER {} \;
find /tmp/ -user $ORIG_UID -exec chown ${NEW_UID}:${NEW_GID} {} \;
find /var/tmp/ -user $ORIG_UID -exec chown ${NEW_UID}:${NEW_GID} {} \;

ls -l /home/ | grep mansible
