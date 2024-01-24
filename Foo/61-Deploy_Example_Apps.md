# Deploy Apps

NOTE:  There are some slight differences (and sometimes significant) between OCP3 and 4.  As I had developed this (initially) with OCP3, I hope to have converted this doc where needed.

## Setup your oc Client Environment
```
su - morpheus
HTPASSWORD=NotAPassword
OCP4API=api.ocp4-mwn.linuxrevolution.com
OCP4APIPORT=6443
echo | openssl s_client -connect $OCP4API:$OCP4APIPORT -servername $OCP4API  | sed -n /BEGIN/,/END/p > ~/$OCP4API.pem
oc login --certificate-authority=$HOME/$OCP4API.pem --username=`whoami` --password=$HTPASSWORD --server=$OCP4API:$OCP4APIPORT
```

Or.. login as kubeadmin
```
USERNAME=kubeadmin
PASSWORD=$(cat $(find ${HOME}/OCP4/*mwn* -name kubeadmin-password | tail -1))
OCP4API=api.ocp4-mwn.linuxrevolution.com
OCP4APIPORT=6443
echo | openssl s_client -connect $OCP4API:$OCP4APIPORT -servername $OCP4API  | sed -n /BEGIN/,/END/p > ~/$OCP4API.pem
oc login --certificate-authority=$HOME/$OCP4API.pem --username=$USERNAME --password=$PASSWORD --server=$OCP4API:$OCP4APIPORT
```

## www_linuxrevolution_com
```
MYPROJ="linrevwelcomepage"
oc new-project $MYPROJ --description="Welcome Page" --display-name="LinuxRevolution Welcome Page" || { echo "ERROR: something went wrong"; exit 9; }
#oc new-app httpd~https://github.com/cloudxabide/www_linuxrevolution_com/
oc new-app php:7.3~https://github.com/cloudxabide/www_linuxrevolution_com/
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "wwwlinuxrevolutioncom", "creationTimestamp": null, "labels": { "app": "wwwlinuxrevolutioncom" } }, "spec": { "host": "www.linuxrevolution.com", "to": { "kind": "Service", "name": "wwwlinuxrevolutioncom" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -
sleep 3
# If you want to test round-robin and app scaling
oc scale deployment/wwwlinuxrevolutioncom --replicas=3
while true; do curl --silent https://www.linuxrevolution.com/phpinfo.php | grep Hostname; sleep 1; done
```

## HexGL
### Create Your Project and Deploy App (HexGL)
```
# HexGL is a HTML5 video game resembling WipeOut from back in the day (Hack the Planet!)
MYPROJ="hexgl"
oc new-project $MYPROJ --description="HexGL Video Game" --display-name="HexGL Game" || { echo "ERROR: something went wrong"; sleep 5; exit 9; }
oc new-app php:7.3~https://github.com/cloudxabide/HexGL.git --image-stream="openshift/php:latest" --strategy=source

# Wait for the build to complete (CrashLoopBackoff is "normal" for this build)
oc get pods -w

# Add a route (hexgl.linuxrevolution.com)
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "hexgl", "creationTimestamp": null, "labels": { "app": "hexgl" } }, "spec": { "host": "hexgl.linuxrevolution.com", "to": { "kind": "Service", "name": "hexgl" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -

# Add a route (hexgl.apps.ocp4-mwn.linuxrevolution.com)
#echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "hexgl", "creationTimestamp": null, "labels": { "app": "hexgl" } }, "spec": { "host": "hexgl.apps.ocp4-mwn.linuxrevolution.com", "to": { "kind": "Service", "name": "hexgl" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -

# Once the app is built (and running) update the deployment
oc scale deployment.apps/php --replicas=0
oc scale deployment.apps/hexgl --replicas=3

-- Or...
oc edit deployment.apps/php
spec: 
  replicas: 0
```

At some point you will be able to browse to (depending on the route you enabled):  
https://hexgl.linuxrevolution.com/



