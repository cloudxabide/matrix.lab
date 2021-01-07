# Usage

A few tips:  
* The may be others using the lab  
* Don't store *any* sensitive data in these systems
  * do not store your AWS creds, ssh keys, etc... in files
  * do not enter any of your creds in to the command line (they will end up in the shell history)
* The bastion is running fail2ban.  So, if you goof up your login to the bastion - it will no longer be available (expected) and let you try again later.

## Asks
* Please provide feedback on the lab.  If you see something that *could* be better, please bring it up (and no, you're not volunteering to fix the issue, just because you bring it up.)
* If you discover something that puts any of us "at risk" (i.e. credentials being stored, etc...) bring that up IMMEDITATELY.  Again, I'll stress - this is a DMZ lab.  It is not secured like a normal lab might be.
