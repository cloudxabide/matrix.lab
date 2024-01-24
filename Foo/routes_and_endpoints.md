# Routes and Endpoints


The following is the routes which exist after a default cluster install.
```
# oc get route --all-namespaces
NAMESPACE                  NAME                    HOST/PORT                                                                  PATH   SERVICES                PORT    TERMINATION            WILDCARD
hexgl                      hexgl                   hexgl.linuxrevolution.com                                                         hexgl                   8080    edge                   None
openshift-authentication   oauth-openshift         oauth-openshift.apps.ocp4-mwn.linuxrevolution.com                                 oauth-openshift         6443    passthrough/Redirect   None
openshift-console          console                 console-openshift-console.apps.ocp4-mwn.linuxrevolution.com                       console                 https   reencrypt/Redirect     None
openshift-console          downloads               downloads-openshift-console.apps.ocp4-mwn.linuxrevolution.com                     downloads               http    edge/Redirect          None
openshift-monitoring       alertmanager-main       alertmanager-main-openshift-monitoring.apps.ocp4-mwn.linuxrevolution.com          alertmanager-main       web     reencrypt/Redirect     None
openshift-monitoring       grafana                 grafana-openshift-monitoring.apps.ocp4-mwn.linuxrevolution.com                    grafana                 https   reencrypt/Redirect     None
openshift-monitoring       prometheus-k8s          prometheus-k8s-openshift-monitoring.apps.ocp4-mwn.linuxrevolution.com             prometheus-k8s          web     reencrypt/Redirect     None
openshift-monitoring       thanos-querier          thanos-querier-openshift-monitoring.apps.ocp4-mwn.linuxrevolution.com             thanos-querier          web     reencrypt/Redirect     None
welcomepage                wwwlinuxrevolutioncom   www.linuxrevolution.com                                                           wwwlinuxrevolutioncom   8080    edge                   None
```

What I'd like to focus on are the 2 "custom" routes from that output
```
hexgl                      hexgl                   hexgl.linuxrevolution.com                                                         hexgl                   8080    edge                   None
welcomepage                wwwlinuxrevolutioncom   www.linuxrevolution.com                                                           wwwlinuxrevolutioncom   8080    edge                   None
```
If you recall, when you created the cluster you defined 2 endpoints:  
* api.{metadata.name}.{baseDomain} = (api.ocp4-mwn.linuxrevolution.com)
* *.apps.{metadata.name}.{baseDomain} = (*.apps.ocp4-mwn.linuxrevolution.com)

based on the values in your install-config.yaml
```
baseDomain: linuxrevolution.com
metadata:
  name: ocp4-mwn
```


