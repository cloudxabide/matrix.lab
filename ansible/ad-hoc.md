# Ad-hoc 

Purpose: Just some examples I want to track

## Ad-Hoc shell commands
```
ansible -i hosts all -a "uptime"
ansible -i hosts all -m shell -a "uptime"
```

## Update Hosts
Update my environment.
Update ALL hosts
Shutdown the VMs
Restart the Virt Hosts (and hope the VMs are configured to auto-start)

```
ansible -i hosts all -m yum -a "name=* state=latest" -b
ansible -i hosts VirtualMachinesAll -a "shutdown now -h"
ansible -i hosts VirtualizationHosts -a "shutdown now -r"
ansible -i hosts all -a "uptime"
```



```
ansible -i hosts lab_nucs -a "shutdown now -h"
```

