# MATRIX.lab (aka LINUXREVOLUTION.COM)
![LinuxRevolution](images/LinuxRevolution_RedGradient.png)  

## Status
Untested.  I am currently making a TON of changes to make my lab "Hybrid".  
Environment is currently being used to test OCP4, RHACM on AWS/on-prem and AWS GovCloud.  
Also - testing NVIDIA Jetson gear, microshift, k3s, SNO (Single-Node OpenShift).  
There is a lot to unpack here...

## Overview
My Homelab dedicated to deploying portions of the Red Hat product portfolio and AWS integration.  
One of the goals (currently) is to build something somewhat "stateless" or shortlived.     
It is primarily an IaaS and PaaS initiative.  This is intended to be a "lab" installation 
- I would not use some of these tactics in a production or business  
environment.  

An obvious question you might ask (if you know that I work for Red Hat, that is):  why am I using VMware?  
First of all: how *dare* you!  And secondly: Great question.  
Answer: Many of my customers who are still hosting on-prem, use VMware.

Lastly, this is NOT a "how-to", an implementation guide, best-practices lab, etc... I do a number of things with this lab I would never do (or recommend/allow anyone else to do) in a business or production environment.

## Products
* Red Hat IdM
* Red Hat OpenShift 4.x
* Red Hat Adv Cluster Management (still needs to be configured though)
* Red Hat Satellite 6.x
* Red Hat Ansible Tower 3.x
* VMware vSphere 6.7 (hosting the OpenShift)
* freeNAS (iSCSI and NFS for OpenShift)
* NVIDIA Jetson JetPack and JetBot

## Hardware
[My Lab Hardware](./hardware.md)

## References
Snazzy "Linux Revolution" logo created at https://fontmeme.com/fonts/mr-robot-font/

## External Repos

| Repo | URL   |
| :--: | :---- |
| EPEL | https://fedoraproject.org/wiki/EPEL |

