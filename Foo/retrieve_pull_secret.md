# Retrieve Pull Secret	


## Using API

Make sure you have jq installed
```
which jq || sudo yum -y install jq
```

then, go here
https://cloud.redhat.com/openshift/token

Copy the token in to your clipboard, save it as...
ocm_api_token.txt

```
OFFLINE_ACCESS_TOKEN=$(cat ocm_api_token.txt)
export BEARER=$(curl \
--silent \
--data-urlencode "grant_type=refresh_token" \
--data-urlencode "client_id=cloud-services" \
--data-urlencode "refresh_token=${OFFLINE_ACCESS_TOKEN}" \
https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token | \
jq -r .access_token)

curl -X POST https://api.openshift.com/api/accounts_mgmt/v1/access_token --header "Content-Type:application/json" --header "Authorization: Bearer $BEARER" | jq
```

