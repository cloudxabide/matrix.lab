# Deploy Wordpress on OpenShift 4

PASSWORD=NotAPassword

OCP4API=api.ocp4-mwn.linuxrevolution.com
OCP4APIPORT=6443
echo | openssl s_client -connect $OCP4API:$OCP4APIPORT -servername $OCP4API  | sed -n /BEGIN/,/END/p > $OCP4API.pem
oc login --certificate-authority=$OCP4API.pem --username=`whoami` --password=$PASSWORD --server=$OCP4API:$OCP4APIPORT


PROJECT=blog-linuxrevolution
mkdir ~/OCP4/$PROJECT; cd $_

screen 
oc new-project $PROJECT

# The following command outputs useful info (DB user/pass/etc...)
oc new-app mariadb-ephemeral

oc new-app php~https://github.com/wordpress/wordpress
oc logs -f dc/wordpress

# Non-TLS
oc expose service wordpress --hostname blog.linuxrevolution.com
# TLS
echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "wordpress-frontend", "creationTimestamp": null, "labels": { "app": "wordpress" } }, "spec": { "host": "blog.linuxrevolution.com", "to": { "kind": "Service", "name": "wordpress" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge" } }, "status": {} } ] }' | oc create -f -

echo '{ "kind": "List", "apiVersion": "v1", "metadata": {}, "items": [ { "kind": "Route", "apiVersion": "v1", "metadata": { "name": "wordpress-frontend", "creationTimestamp": null, "labels": { "app": "wordpress" } }, "spec": { "host": "blog.linuxrevolution.com", "to": { "kind": "Service", "name": "wordpress" }, "port": { "targetPort": 8080 }, "tls": { "termination": "edge", "insecureEdgeTerminationPolicy": "Allow" } }, "status": {} } ] }' | oc create -f -
# UPdate the following to use envsubst or something to replace value(s)

Browse to
https://blog.linuxrevolution.com

Enter "mariadb:3306/" for the Database Connection


