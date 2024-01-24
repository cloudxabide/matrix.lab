# Getting Started

This is a work in progress - but, should be pretty accurate/done.

## Overview
There are serveral methods for connecting to the lab (depending on what you need to):

*  console/webUI (OpenShift, for example)
*  ssh (only ssh-key auth is allowed)
*  VPN (need VPN client (and certs)), if you need access to browse endpoints other than OCP

## Are you locked out?
Fail2Ban is running - so, if you bork up your login a few times trying to get in, you might get locked out for a bit.  

Don't break the bastion (vpn.linuxrevolution.com / rh8-util-srv01)  

You will connect to the bastion (as yourself) and from there you can access all/most resources in the lab.

If you are VPN'd in, Browse here:  http://10.10.10.10 - you will find links to most of the important resources. 

If you need/want access, just email James.


mansible@rh8-util-srv01 has an Ansible inventory ready to "go do things(tm)"

## Usage

A few tips:  
* The may be others using the lab  
* Don't store *any* sensitive data in these systems
  * do not store your AWS creds, ssh keys, etc... in files
  * do not enter any of your creds in to the command line (they will end up in the shell history)
* The bastion is running fail2ban.  So, if you goof up your login to the bastion - it will no longer be available (expected) and let you try again later.

## Asks
* Please provide feedback on the lab.  If you see something that *could* be better, please bring it up (and no, you're not volunteering to fix the issue, just because you bring it up.)
* If you discover something that puts any of us "at risk" (i.e. credentials being stored, etc...) bring that up IMMEDITATELY.  Again, I'll stress - this is a DMZ lab.  It is not secured like a normal lab might be.
