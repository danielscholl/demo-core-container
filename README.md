# demo-core-container

A Sample ASP.NET Core App with build and deploy pipelines.

## Windows Container Usage

Build the Image

```
docker-compose -f windows-compose.yml build
```

## Linux Container Usage

Build the Image

```
docker-compose -f linux-compose.yml build
```

## Deploy the Resources

```bash
NAME="demo-core-container"
UNIQUE=123
PRINCIPAL="http://${NAME}-${UNIQUE}"

# Create a Service Principal for Registry
CLIENT_SECRET=$(az ad sp create-for-rbac --name $PRINCPAL --skip-assignment --query password -otsv)
CLIENT_ID=$(az ad sp list --display-name $PRINCIPAL --query [].appId -otsv)
OBJECT_ID=$(az ad sp list --display-name $PRINCIPAL --query [].objectId -otsv)
USER_ID=$(az ad user show --upn-or-object-id $(az account show --query user.name -otsv) --query objectId -otsv)

# Create Azure Resources  (KV, VNET, REGISTRY)
az deployment create --template-file azuredeploy.json --location eastus2 \
  --parameters random=$UNIQUE \
  --parameters servicePrincipalClientId=$CLIENT_ID \
  --parameters servicePrincipalClientKey=$CLIENT_SECRET \
  --parameters servicePrincipalObjectId=$OBJECT_ID \
  --parameters userObjectId=$USER_ID
```

## Build Images and publish to Registry

```bash
IMAGE="demo-core-container"
REGISTRY=${UNIQUE}registry

# Login to the Container Registry
az acr login --name $REGISTRY

# Build and Push Image
az acr run -r $REGISTRY -f build.yaml .
```


## Deploy the Container to Azure Container Instancs

```bash
VAULT=$(az keyvault list --resource-group $NAME-$UNIQUE -otable --query [].name -otsv)

az container create \
    --resource-group $NAME-$UNIQUE \
    --name $NAME-$UNIQUE \
    --image $REGISTRY.azurecr.io/$IMAGE:latest \
    --registry-login-server $REGISTRY.azurecr.io \
    --registry-username $(az keyvault secret show --vault-name $VAULT --name clientId --query value -o tsv) \
    --registry-password $(az keyvault secret show --vault-name $VAULT --name clientSecret --query value -o tsv) \
    --dns-name-label $NAME-$UNIQUE \
    --query "{FQDN:ipAddress.fqdn}" \
    --output table


```
