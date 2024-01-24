# Infra stuff for 3scale

3scale requires RWX storage, which I will use NFS to provide (or attempt to)


```
mkdir ${OCP4_DIR}/3scale; cd $_
cat << EOF > 3scale-data-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: 3scale-data-pv
spec:
  accessModes:
    - ReadWriteMany
  capacity:
      storage: 100Gi
  nfs:
    path: /mnt/raidZ/3scale
    server: 10.10.10.19
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs-3scale
EOF

cat << EOF > 3scale-data-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: 3scale-data-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  volumeMode: Filesystem
  storageClassName: nfs-3scale
EOF
```

### Create and Validate the PV/PVC
NOTE:  You (obviously) would need a namespace to create the PVC in
```
kubectl apply -f 3scale-data-pv.yaml
kubectl -n openshift-3scale-data apply -f 3scale-data-pvc.yaml
kubectl -n openshift-3scale-data get pvc
```
