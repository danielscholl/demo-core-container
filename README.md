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

CLIENT_SECRET=$(az ad sp create-for-rbac --name $PRINCPAL --skip-assignment --query password -otsv)
CLIENT_ID=$(az ad sp list --display-name $PRINCIPAL --query [].appId -otsv)
OBJECT_ID=$(az ad sp list --display-name $PRINCIPAL --query [].objectId -otsv)

az deployment create --template-file azuredeploy.json --location eastus --random $UNIQUE \
  --parameters servicePrincipalClientId=$CLIENT_ID \
  --parameters servicePrincipalClientKey=$CLIENT_SECRET \
  --parameters servicePrincipalObjectId=$OBJECT_ID


```

## Build Images and publish to Registry

```bash
# Login to the Container Registry
REGISTRY=${UNIQUE}registry
IMAGE="demo-core-container"
az acr login --name $REGISTRY

# Build Image
az acr run -r $REGISTRY build.yaml .
```
