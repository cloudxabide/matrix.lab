# vSphere Storage Foo
If you had built your cluster using IPI, then the storage class is already configured
```
$ oc get sc
NAME             PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
thin (default)   kubernetes.io/vsphere-volume   Delete          Immediate           false                  4d13h
```

However, if you need to create your own storageclass (sc)
```
cat << EOF > sc-vsphere.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: slow
provisioner: kubernetes.io/vsphere-volume 
parameters:
  diskformat: thin 
EOF
```

## References
https://docs.openshift.com/container-platform/4.6/storage/dynamic-provisioning.html  
https://docs.openshift.com/container-platform/4.6/post_installation_configuration/storage-configuration.html

