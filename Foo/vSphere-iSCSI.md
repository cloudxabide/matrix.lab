# vSphere iSCSI 

Something I am creating to remember how to configure iSCSI multipathing with my FreeNAS and VMware hosts

Add vSwitch:  vSwitch-1
              vmnic1

Add Port Group:
iSCSI-P1
iSCSI-P2

Add VMkernel NIC
Port group: iSCSI-P1


Add Distributed Switch
Dswitch-Guests


Add Host to Distributed Switch
0 - management / VM Network
1 - iSCSI P1
4 - iSCSI P2
