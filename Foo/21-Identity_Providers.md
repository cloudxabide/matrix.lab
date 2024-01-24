# Identity Providers

## Caveats
Using the methods below are singleton activities (i.e. if you do htpasswd after IDM, it overwrites the IDM)
You need to do one method first, then use the CR at the bottom

## Red Hat Identity Management

### Prereqs

* Create an openshift-admins group
* add ocpadmin to the openshift-admins group
* create ocp-connector user

using the following as a "base" query to start from
```
ldapsearch -D "cn=Directory Manager" -w "NotAPassword" -p 389 -h rh8-idm-srv01.matrix.lab  -b "dc=matrix,dc=lab" -s sub -x "(objectclass=*)" | grep dn:
```

```
ldapsearch -D "cn=Directory Manager" -W -p 389 -h rh8-idm-srv01.matrix.lab  -b "dc=matrix,dc=lab" -s sub -x "(objectclass=*)" | grep "dn: uid"  | grep ocp-connect | grep -v compat 
ldapsearch -D "cn=Directory Manager" -W -p 389 -h rh8-idm-srv01.matrix.lab  -b "cn=openshift-admins,cn=groups,cn=accounts,dc=matrix,dc=lab" 
```

Then... as the "bind user"
```
BINDPASSWD=NotAPassword
# This, in my case, will show 2 users (ocpadmin and morpheus)
ldapsearch -x -LLL -D "uid=ocp-connector,cn=users,cn=accounts,dc=matrix,dc=lab" -W -p 389 -h rh8-idm-srv01.matrix.lab  -s sub "(|(memberof=cn=openshift-dev,cn=groups,cn=accounts,dc=matrix,dc=lab)(memberof=cn=openshift-admins,cn=groups,cn=accounts,dc=matrix,dc=lab))" "CN"

# Using the "CN: " from the last command, run ...
ldapsearch -x -LLL -D "uid=ocp-connector,cn=users,cn=accounts,dc=matrix,dc=lab" -W -p 389 -h rh8-idm-srv01.matrix.lab  -s sub "cn=ocpadmin"
ldapsearch -x -LLL -D "uid=ocp-connector,cn=users,cn=accounts,dc=matrix,dc=lab" -W -p 389 -h rh8-idm-srv01.matrix.lab  -s sub "cn=morpheus"

```

### Create OpenShift Resources

#### Create Secret
```
oc create secret generic idm-ldap-secret --from-literal=bindPassword=$BINDPASSWD -n openshift-config 
```

#### Create configMap

```
cd $OCP4_DIR
IDMURL=rh8-idm-srv01.matrix.lab
wget --no-check-certificate -O MATRIXLAB-ca.crt http://$IDMURL/ipa/config/ca.crt
openssl x509 -in MATRIXLAB-ca.crt -noout -text
```

#### Custom Resource
```
oc create configmap idm-ca-config-map --from-file=ca.crt=./MATRIXLAB-ca.crt -n openshift-config
cat << EOF > idp-cr-idm.yaml
---
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: RedHatIdM
    mappingMethod: claim 
    type: LDAP
    ldap:
      attributes:
        id: 
        - dn 
        email: 
        - mail
        name: 
        - cn
        preferredUsername: 
        - uid
      bindDN: 'uid=ocp-connector,cn=users,cn=accounts,dc=matrix,dc=lab'
      bindPassword: 
        name: idm-ldap-secret
      ca: 
        name: idm-ca-config-map
      insecure: false 
      url: 'ldap://rh8-idm-srv01.matrix.lab/cn=accounts,dc=matrix,dc=lab'
EOF
      #url: 'ldap://rh8-idm-srv01.matrix.lab/cn=groups,cn=accounts,dc=matrix,dc=lab?CN??(|(memberof=cn=openshift-dev,cn=groups,cn=accounts,dc=matrix,dc=lab)(memberof=cn=openshift-admins,cn=groups,cn=accounts,dc=matrix,dc=lab))'

oc apply -f idp-cr-idm.yaml
# Watch the pods until they "re-settle" (about 1 minute until they start to terminate and redeploy)
oc get pods -n openshift-authentication -w

cat << EOF > $OCP4_DIR/ldap_sync.yaml
 kind: LDAPSyncConfig
 apiVersion: v1
 url: ldap://rh8-idm-srv01.matrix.lab/cn=groups,cn=accounts,dc=matrix,dc=lab
 insecure: true
 rfc2307:
   groupsQuery:
     baseDN: cn=groups,cn=accounts,dc=matrix,dc=lab
     scope: sub
     timeout: 0
     derefAliases: always
     filter: (objectClass=*)
     pageSize: 0
   groupUIDAttribute: dn
   groupNameAttributes: [cn]
   groupMembershipAttributes: [member]
   usersQuery:
     baseDN: cn=users,cn=accounts,dc=matrix,dc=lab
     scope: one
     derefAliases: always
     pageSize: 0
   userUIDAttribute: dn
   userNameAttributes: [uid]
   tolerateMemberNotFoundErrors: true
   tolerateMemberOutOfScopeErrors: true
EOF
oc adm groups sync --sync-config=$OCP4_DIR/ldap_sync.yaml --confirm
```

## Add htpasswd
### Create an HTPASSWD file

```
HTPASSWORD=""
HTPASSWD_FILE=${OCP4_DIR}/htpasswd

htpasswd -b -c $HTPASSWD_FILE morpheus $HTPASSWORD
htpasswd -b $HTPASSWD_FILE ocpguest $HTPASSWORD
htpasswd -b $HTPASSWD_FILE ocpadmin $HTPASSWORD

oc create secret generic htpass-secret --from-file=htpasswd=${HTPASSWD_FILE} -n openshift-config
cat << EOF > ${OCP4_DIR}/idp-cr-HTPasswd.yaml
---
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: HTPasswd 
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
EOF

oc apply -f ${OCP4_DIR}/idp-cr-HTPasswd.yaml
# Watch the pods until they "re-settle" before proceeding - usually like 2 minutes?
oc get pods -n openshift-authentication -w

# Wait until the authentication cluster operator is done updating, then run...
# You need to login to the cluster with 'ocpadmin' user
sudo su - -c "oc login -u ocpadmin -p $HTPASSWORD --server=$OCP4API:$OCP4APIPORT"
oc adm policy add-cluster-role-to-user cluster-admin ocpadmin
```

## Both HTPASSWD and RHIDM
```
cat << EOF > idp-cr-both.yaml
---
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: HTPasswd
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
  - name: RedHatIdM
    mappingMethod: claim
    type: LDAP
    ldap:
      attributes:
        id:
        - dn
        email:
        - mail
        name:
        - cn
        preferredUsername:
        - uid
      bindDN: 'uid=ocp-connector,cn=users,cn=accounts,dc=matrix,dc=lab'
      bindPassword:
        name: idm-ldap-secret
      ca:
        name: idm-ca-config-map
      insecure: false
      url: 'ldap://rh8-idm-srv01.matrix.lab/cn=accounts,dc=matrix,dc=lab'
EOF
oc apply -f idp-cr-both.yaml
```

## References
https://access.redhat.com/documentation/en-us/red_hat_directory_server/11/html/administration_guide/examples-of-common-ldapsearches   
https://docs.openshift.com/container-platform/4.10/authentication/identity_providers/configuring-ldap-identity-provider.html   
https://developers.redhat.com/blog/2019/08/02/how-to-configure-ldap-user-authentication-and-rbac-in-red-hat-openshift-3-11#ldap_details  

