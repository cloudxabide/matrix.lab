kinit admin

ipa dnszone-add example.lab                 --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add ocp4.example.lab        --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add apps.ocp4.example.lab   --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true
ipa dnszone-add proles.ocp4.example.lab --admin-email=root@matrix.lab --minimum=3000 --dynamic-update=true

ipa dnsrecord-add   example.lab                  '*'       --a-rec    10.10.10.150
ipa dnsrecord-add   ocp4.example.lab             'api'     --a-rec    10.10.10.150
ipa dnsrecord-add   ocp4.example.lab             'api-int' --a-rec    10.10.10.150
ipa dnsrecord-add   apps.ocp4.example.lab        '*'       --a-rec    10.10.10.150

ipa dnsrecord-add   ocp4.example.lab             bastion    --a-rec    10.10.10.149
ipa dnsrecord-add   ocp4.example.lab             proxy      --a-rec    10.10.10.150
ipa dnsrecord-add   ocp4.example.lab             boostrap   --a-rec    10.10.10.151
ipa dnsrecord-add   ocp4.example.lab             master0    --a-rec    10.10.10.152
ipa dnsrecord-add   ocp4.example.lab             master1    --a-rec    10.10.10.153
ipa dnsrecord-add   ocp4.example.lab             master2    --a-rec    10.10.10.154
ipa dnsrecord-add   ocp4.example.lab             etcd0      --a-rec    10.10.10.152
ipa dnsrecord-add   ocp4.example.lab             etcd1      --a-rec    10.10.10.153
ipa dnsrecord-add   ocp4.example.lab             etcd2      --a-rec    10.10.10.154
ipa dnsrecord-add   ocp4.example.lab             worker0    --a-rec    10.10.10.155
ipa dnsrecord-add   ocp4.example.lab             worker1    --a-rec    10.10.10.156
ipa dnsrecord-add   ocp4.example.lab             worker2    --a-rec    10.10.10.157

ipa dnsrecord-add   10.10.10.in-addr.arpa        149       --ptr-rec  bastion.ocp4.example.lab
ipa dnsrecord-add   10.10.10.in-addr.arpa        150       --ptr-rec  proxy.ocp4.example.lab
ipa dnsrecord-add   10.10.10.in-addr.arpa        151       --ptr-rec  bootstrap.ocp4.example.lab
ipa dnsrecord-add   10.10.10.in-addr.arpa        152       --ptr-rec  master0.ocp4.example.lab
ipa dnsrecord-add   10.10.10.in-addr.arpa        153       --ptr-rec  master1.ocp4.example.lab
ipa dnsrecord-add   10.10.10.in-addr.arpa        154       --ptr-rec  master2.ocp4.example.lab
ipa dnsrecord-add   10.10.10.in-addr.arpa        155       --ptr-rec  worker0.ocp4.example.lab
ipa dnsrecord-add   10.10.10.in-addr.arpa        156       --ptr-rec  worker1.ocp4.example.lab
ipa dnsrecord-add   10.10.10.in-addr.arpa        157       --ptr-rec  worker2.ocp4.example.lab

ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' example.lab
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' ocp4.example.lab
ipa dnszone-mod --allow-transfer='192.168.0.0/24;10.10.10.0/24;127.0.0.1' apps.ocp4.example.lab

#ipa dnsrecord-add   proles.ocp4.example.lab      '*'       --a-rec    10.10.10.149
#ipa dnsrecord-add   10.10.10.in-addr.arpa        149       --ptr-rec  *.proles.ocp4.example.lab
