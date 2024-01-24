# networking

## Subnets
10.10.10.0/24 - Primary DMZ Subnet  
10.10.69.0/24 - VPN   
10.10.10.1 - Gateway  

## DNS and Domains
| Domain                  | Purpose                                                | Provider/Service
|:------------------------|:-------------------------------------------------------|:----------------:|
| matrix.lab              | Internal Only domain I use for my lab                  | Red Hat IdM      |
| jetsons.lab             | Internal Only domain I use for my NVIDIA Jetsons       | Red Hat IdM      |
| linuxrevolution.com     | External (and now Internal) domain I use for.. testing | AWS Route 53     |
| clouditoutloud.com      | External (only) domain for AWS resources               | AWS Route 53     |
| gov.clouditoutloud.com  | External (only) domain for AWS resources in GovCloud   | AWS Route 53     |

## Network Services (infrastructure)

| Service        | Purpose                           | Host(s)                                       |
|:---------------|:----------------------------------|:----------------------------------------------|
| NTP            | Network Time Protocol             | 10.10.10.10 <BR> 10.10.10.17 <BR> 10.10.10.19 |
| DNS            | Domain Name Service               | 10.10.10.121 <BR> 10.10.10.122                |
| Auth           | Authentication <BR> Authorization | 10.10.10.121 <BR> 10.10.10.122                |
| PXE, TFTP, WWW | Kickstart for network             | 10.10.10.10 (*)                               |
| DHCP           | IP addresses for Guests           | 10.10.10.192-248                              |

* otherwise: 10.10.10.102 if Satellite is configured to provide Provisioning
## Infrastructure Hosts
| Hostname          |            Product              |  Purpose             | Proc, Mem Size | Hypervisor |
| :---------------- |:-------------------------------:|:--------------------:| --------------:|:----------:|
| RH7-IDM-SRV01     | Red Hat Identity Management     | IdM and DNS          | 2, 1024m       | zion       |
| RH8-UTIL-SRV01    | Red Hat Enteprise Linux         | Util, DMZ Bastion    | 2, 1024m       | zion       |
| ----------------- | -----------------------------   | -------------------  | -------------- | ---------- |
| RH7-IDM-SRV02     | Red Hat Identity Management     | IdM and DNS          | 2, 1024m       | sati       |
| RH7-LMS-SRV01     | libreNMS                        | Monitoring           | 2, 1024m       | zion       |
| ----------------- | -----------------------------   | -------------------  | -------------- | ---------- |
| RH7-SAT6-SRV01    | Red Hat Satellite 6             | Host Management      | 2, 10240m      | tank       |
| RH7-ANS-SRV01     | Red Hat Ansible                 | Host Management      | 2, 4096m       | sati       |

---
## Network Overview (physical)
primarily for the "NAS/SAN" interfaces.

## Switch Layout - Cisco SG300-28 (RHHI-V and Guest interfaces)
| Switch Port | Host     | Host Int | LAG | Switch Port | Host      | Host Int | LAG |
|:-----------:|:--------:|:--------:|:---:|:-----------:|:---------:|:--------:|:---:|
|  gi1        | apoc     | ne1000   |     | gi2         | apoc      | qflge0   |     |
|  gi3        | apoc     | qflge1   |     | gi4         | apoc      | qflge2   |     |
|  gi5        | apoc     | qflge3   |     | gi6         | e-meter   |          |     |
|  gi7        |          |          |     | gi8         | dozer     | vmnic0   |     |
|  gi9        | dozer    | vmnic1   |     | gi10        | dozer     | vmnic2   |     |
|  gi11       | dozer    | vmnic3   |     | gi12        | dozer     | vmnic4   |     |
|  gi13       |          |          |     | gi14        | seraph    | em0      |     |
|  gi15       | tank     | vmnic3   |     | gi16        | tank      | vmnic4   |     |
|  gi17       | tank     | vmnic0   |     | gi18        | tank      | vmnic1   |     |
|  gi19       | tank     | vmnic2   |     | gi20        | tank      | vmnic3   |     |
|  gi21       | seraph   | em1      |  1  | gi22        | seraph    | em2      |  1  |
|  gi23       | seraph   | bge0     |  1  | gi24        | seraph    | bge1     |  1  |
|   -         |    -     |    -     |  -  |   -         |           |    --    |     |
|  gi25       |    -     |    -     |     | gi26        | uplink-router |      |    --    |     |
|  gi27       |          |          |     | gi28        |           |      |    --    |     |

### 802.3ad LAG groups (configured on Mr Switch)
| LAG  | Name
|:----:|:------
| LAG1 | FREENAS
| LAG2 | unassigned
| LAG3 | unassigned
| LAG4 | unassigned
| LAG5 | unassigned
| LAG6 | unassigned
| LAG7 | unassigned
| LAG8 | unassigned
