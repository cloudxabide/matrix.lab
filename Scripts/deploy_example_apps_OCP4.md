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

MYPROJ="cxawelcomepage"
oc new-project $MYPROJ --description="Welcome Page - cloudXabide" --display-name="cloudXabide Welcome Page" || { echo "ERROR: something went wrong"; exit 9; }
oc new-app php:7.3~https://github.com/cloudxabide/www_cloudxabide_com/

# The following publishes on both 80 and 443 (www.cloudxabide.com) with "edge" termination
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "80-443-www-cxa", "creationTimestamp": null, "labels": { "app": "wwwcloudxabidecom" } }, "spec": { "host": "www.cloudxabide.com", "to": { "kind": "Service", "name": "wwwcloudxabidecom" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge", "insecureEdgeTerminationPolicy": "Allow" } }, "status": {} } ] }' | oc create -f -

# The following publishes on both 80 and 443 (www.cloudxabide.com) with "re-encrypt" termination (Work In Progress)
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "http-tld-cxa", "creationTimestamp": null, "labels": { "app": "wwwcloudxabidecom" } }, "spec": { "host": "www.cloudxabide.com", "to": { "kind": "Service", "name": "wwwcloudxabidecom" }, "port": { "targetPort": 8080 }, "tls": { "termination": "reencrypt" } }, "status": {} } ] }' | oc create -f -

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

## Mattermost 
forked from - https://github.com/goern/mattermost-openshift.git   
I had to make the following changes and updates from the original source (my source (below) already has this update)
```
# Not sure why the DB is named incorrectly
sed -i -e 's/mattermost_test/mattermost/g' mattermost.yaml
# Need edge termination as I do not allow HTTP through my firewall
sed -i -e 's/targetPort: 8065/targetPort: 8065\n      tls:\n        termination: edge/g' mattermost.yaml
```

As user:morpheus clone the repo, create the project "mattermost"
```
cd ${HOME}; git clone https://github.com/cloudxabide/mattermost-openshift.git; cd mattermost-openshift/
oc new-project mattermost
oc new-app postgresql-persistent -p POSTGRESQL_USER=mmuser \
                                 -p POSTGRESQL_PASSWORD=mostest \
                                 -p POSTGRESQL_DATABASE=mattermost \
                                 -p MEMORY_LIMIT=512Mi
```

As system:admin modify SCC (Do NOT do this in a Production Environment) 
NOTE: you NEED to wait for the database to be deployed  
```
oc annotate namespace mattermost openshift.io/sa.scc.uid-range=1001/1001 --overwrite
oc adm policy add-scc-to-user anyuid system:serviceaccount:mattermost:mattermost
```

As user:morpheus create the mattermost app (and add ImageStream)
```
oc create --filename mattermost.yaml
oc create serviceaccount mattermost
oc create secret generic mattermost-database --from-literal=user=mmuser --from-literal=password=mostest
oc secrets link mattermost mattermost-database

oc new-app --template=mattermost --labels=app=mattermost
oc tag mattermost:5.2-PCP mattermost:latest
oc expose service/mattermost --labels=app=mattermost
```


### Fix the Route (add edge termination)
As system:admin add tls:termination:edge 
```
oc delete route mattermost
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "mattermost", "creationTimestamp": null, "labels": { "app": "mattermost" } }, "spec": { "host": "mattermost.linuxrevolution.com", "to": { "kind": "Service", "name": "mattermost" }, "port": { "targetPort": "8065-tcp" }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -
```

#### Manual Update (optional)
```
oc edit route -n mattermost
  port:
    targetPort: 8065-tcp
>>>>>
  tls:
    termination: edge
<<<<<<
# Optional - update host name
  host: mattermost.linuxrevolution.com

```

### Enjoy
https://mattermost.linuxrevolution.com  
Or the default URL  
https://mattermost-mattermost.ocp3-mwn.linuxrevolution.com

### Cleanup
```
oc project mattermost
oc delete all --all
oc delete pvc postgresql -n mattermost
oc project hexgl
oc delete project mattermost
```

## RocketChat
Status:  Work in Progress

I believe you will only be able to do this from a node in the cluster... (i.e. not the bastion)
```
docker pull rocketchat/rocket.chat
docker tag rocketchat/rocket.chat hub.openshift.rhel-cdk.10.1.2.2.xip.io/openshift/rocket-chat
docker push hub.openshift.rhel-cdk.10.1.2.2.xip.io/openshift/rocket-chat
```

user: morpheus
```
oc login {blah}
oc new-project rocket-chat

git clone https://github.com/rimolive/rocketchat-openshift
cd rocketchat-openshift
oc create -n openshift -f rocket-chat-is.json
oc create -n openshift -f rocket-chat-ephemeral.json
oc new-app rocket-chat -p MONGODB_DATABASE=rocketchat \
                       -p MONGODB_USER=rocketchat-admin \
                        -p MONGODB_PASSWORD=rocketchat 

