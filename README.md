# demo-core-container

A Sample ASP.NET Core App with build and deploy pipelines.

## Deploy the Resources

```bash
UNIQUE=123
NAME="demo-core-container"
PRINCIPAL="http://${NAME}-${UNIQUE}"

# Create a Service Principal for Registry
CLIENT_SECRET=$(az ad sp create-for-rbac --name $PRINCIPAL --skip-assignment --query password -otsv)
CLIENT_ID=$(az ad sp list --display-name $NAME --query [].appId -otsv)
OBJECT_ID=$(az ad sp list --display-name $NAME --query [].objectId -otsv)
USER_ID=$(az ad user show --upn-or-object-id $(az account show --query user.name -otsv) --query objectId -otsv)

# Create Azure Resources  (KV, VNET, REGISTRY)
az deployment create --template-file azuredeploy.json --location eastus2 \
  --parameters random=$UNIQUE --parameters group="${NAME}-$UNIQUE" \
  --parameters servicePrincipalClientId=$CLIENT_ID \
  --parameters servicePrincipalClientKey=$CLIENT_SECRET \
  --parameters servicePrincipalObjectId=$OBJECT_ID \
  --parameters userObjectId=$USER_ID
```

## Build Images and publish to Registry

```bash

REGISTRY=$(az acr list --resource-group ${NAME}-$UNIQUE --query [].name -otsv)

# Login to the Container Registry
az acr login --name $REGISTRY

# Build and Push Image
az acr run -r $REGISTRY -f sample.yaml .
```


## Deploy the Container to Azure Container Instancs

```bash
VAULT=$(az keyvault list --resource-group ${PWD##*/}-$UNIQUE  -otable --query [].name -otsv)

az container create \
    --resource-group ${PWD##*/}-$UNIQUE \
    --name ${PWD##*/}-$UNIQUE \
    --image $REGISTRY.azurecr.io/sample:latest \
    --registry-login-server $REGISTRY.azurecr.io \
    --registry-username $(az keyvault secret show --vault-name $VAULT --name clientId --query value -o tsv) \
    --registry-password $(az keyvault secret show --vault-name $VAULT --name clientSecret --query value -o tsv) \
    --dns-name-label ${PWD##*/}$UNIQUE \
    --query "{FQDN:ipAddress.fqdn}" \
    --output table
```
