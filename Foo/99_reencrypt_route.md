# reencrypt Route

Put this together to add a Let's Encrypt Cert to my cloudXabide.com domain 

```
oc create route reencrypt --service=frontend \
  --cert=tls.crt \  << TLS Cert
  --key=tls.key  \  << TLS Key
  --dest-ca-cert=destca.crt  \  << Fullchain CA Cert 
  --ca-cert=ca.crt \            << Intermediate CA Cert (certificate authorities certificate)
  --hostname=www.example.com
```

```
oc create route reencrypt --service=wwwcloudxabidecom \
  --cert=/home/morpheus/.acme.sh/cloudxabide.com/cloudxabide.com.cer \
  --key=/home/morpheus/.acme.sh/cloudxabide.com/cloudxabide.com.key \
  --dest-ca-cert=/home/morpheus/.acme.sh/cloudxabide.com/fullchain.cer \
  --ca-cert=/home/morpheus/.acme.sh/cloudxabide.com/ca.cer \
  --hostname=www.cloudxabide.com
```

Then test
```
curl https://www.cloudxabide.com/ --resolve 'www.cloudxabide.com:443:10.10.10.162'
```

```
[Sat Sep 25 12:49:22 EDT 2021] Your cert is in: /home/morpheus/.acme.sh/cloudxabide.com/cloudxabide.com.cer 
[Sat Sep 25 12:49:22 EDT 2021] Your cert key is in: /home/morpheus/.acme.sh/cloudxabide.com/cloudxabide.com.key
[Sat Sep 25 12:49:22 EDT 2021] The intermediate CA cert is in: /home/morpheus/.acme.sh/cloudxabide.com/ca.cer
[Sat Sep 25 12:49:22 EDT 2021] And the full chain certs is there: /home/morpheus/.acme.sh/cloudxabide.com/fullchain.cer
```
