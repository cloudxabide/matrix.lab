#!/bin/bash

SRCHOST="zion.matrix.lab"
RSYNC_OPTS=" --delete "
mkdir -p etc etc/dhcp var/lib/tftpboot/efi/  etc/httpd/conf.d/

rsync -tugrpolvv $RSYNC_OPTS ${SRCHOST}:/etc/fstab  etc/
rsync -tugrpolvv $RSYNC_OPTS ${SRCHOST}:/etc/dhcp/*.conf etc/dhcp/
rsync -tugrpolvv $RSYNC_OPTS ${SRCHOST}:/var/lib/tftpboot/efi/grub* var/lib/tftpboot/efi/
rsync -tugrpolvv $RSYNC_OPTS ${SRCHOST}:/etc/httpd/conf.d/*.conf etc/httpd/conf.d/
rsync -tugrpolvv $RSYNC_OPTS ${SRCHOST}:/data/ISOS/index.php index.php 
