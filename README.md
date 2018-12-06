# demo-core-container

A Sample ASP.NET Core App with build and deploy pipelines.

[![Build Status](https://cloudcodeit.visualstudio.com/DemoStuff/_apis/build/status/danielscholl.demo-core-container)](https://cloudcodeit.visualstudio.com/DemoStuff/_build/latest?definitionId=30)

## Deploy the Resources

_Bash with Azure CLI_
```bash
UNIQUE=123
NAME="demo-core-container"
PRINCIPAL="http://${NAME}-${UNIQUE}"

# Create a Service Principal for Registry
CLIENT_SECRET=$(az ad sp create-for-rbac --name $PRINCIPAL --skip-assignment --query password -otsv)
CLIENT_ID=$(az ad sp list --display-name $NAME-$UNIQUE --query [].appId -otsv)
OBJECT_ID=$(az ad sp list --display-name $NAME-$UNIQUE --query [].objectId -otsv)
USER_ID=$(az ad user show --upn-or-object-id $(az account show --query user.name -otsv) --query objectId -otsv)

# Create Azure Resources  (KV, VNET, REGISTRY)
az deployment create --template-file azuredeploy.json --location eastus2 \
  --parameters random=$UNIQUE --parameters group="$NAME-$UNIQUE" \
  --parameters servicePrincipalClientId=$CLIENT_ID \
  --parameters servicePrincipalClientKey=$CLIENT_SECRET \
  --parameters servicePrincipalObjectId=$OBJECT_ID \
  --parameters userObjectId=$USER_ID
```

_PowerShell with AZ Module_
```powershell
$UNIQUE = 321
$NAME = "demo-core-container"
$PASSWORD = [guid]::NewGuid().Guid
$SECPASS = ConvertTo-SecureString $PASSWORD -AsPlainText -Force
$PRINCIPAL = New-AzADServicePrincipal -DisplayName "${NAME}-${UNIQUE}" -Password $SECPASS
$USER = Get-AzADUser -UPN $(Get-AzContext).Account

New-AzDeployment -Name $NAME `
  -TemplateFile azuredeploy.json -location eastus2 `
  -random $UNIQUE -group "${NAME}-$UNIQUE"`
  -servicePrincipalClientId $PRINCIPAL.ApplicationId `
  -servicePrincipalClientKey $PASSWORD `
  -servicePrincipalObjectId $PRINCIPAL.Id  `
  -userObjectId $USER.Id
```

## Build Images and publish to Registry

_Bash with Azure CLI_
```bash
REGISTRY=$(az acr list --resource-group $NAME-$UNIQUE --query [].name -otsv)
VAULT=$(az keyvault list --resource-group $NAME-$UNIQUE  -otable --query [].name -otsv)

# Save Registry Info to Key Vault
az keyvault secret set --vault-name $VAULT --name containerRegistry --value $(az acr list --resource-group ${NAME}-$UNIQUE --query [].loginServer -otsv)

# Login to the Container Registry
az acr login --name $REGISTRY

# Build and Push Image
az acr run -r $REGISTRY -f linux-build.yaml .
```

_PowerShell with AZ Module_
```powershell
$REGISTRY = Get-AzContainerRegistry -ResourceGroup $NAME-$UNIQUE
$VAULT = Get-AzKeyVault -ResourceGroupName $NAME-$UNIQUE
$SECRETVALUE = ConvertTo-SecureString $REGISTRY.LoginServer -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $VAULT.VaultName -Name 'containerRegistry' -SecretValue $SECRETVALUE

$creds = Get-AzContainerRegistryCredential -Registry $REGISTRY
$server = $REGISTRY.LoginServer

$creds.Password | docker login $server -u $creds.Username --password-stdin
docker build -t $server/demo-core-container:latest -f windows.Dockerfile .
docker push $server/demo-core-container:latest
```

## Deploy the Container to Azure Container Instances

```bash
VNET=$(az network vnet list --resource-group $NAME-$UNIQUE --query [].name -otsv)

# Deploy a Container on Public Network
az container create \
    --resource-group $NAME-$UNIQUE \
    --name $NAME-$UNIQUE-public \
    --image $REGISTRY.azurecr.io/demo-core-container:latest \
    --registry-login-server $REGISTRY.azurecr.io \
    --registry-username $(az keyvault secret show --vault-name $VAULT --name clientId --query value -o tsv) \
    --registry-password $(az keyvault secret show --vault-name $VAULT --name clientSecret --query value -o tsv) \
    --dns-name-label $NAME$UNIQUE \
    --query "{FQDN:ipAddress.fqdn}" \
    --output table

# Deploy a Container on Private Network
az container create \
    --resource-group $NAME-$UNIQUE \
    --name $NAME-$UNIQUE-private \
    --image $REGISTRY.azurecr.io/demo-core-container:latest \
    --registry-login-server $REGISTRY.azurecr.io \
    --registry-username $(az keyvault secret show --vault-name $VAULT --name clientId --query value -o tsv) \
    --registry-password $(az keyvault secret show --vault-name $VAULT --name clientSecret --query value -o tsv) \
    --vnet $VNET \
    --subnet containerSubnet \
    --query "{FQDN:ipAddress.fqdn}" \
    --output table
```

_PowerShell with AZ Module_
> TODO

-------------

## Issue List

1. ACR does not currently build Windows Containers

1. ACI Windows Containers does not currently support VNET Integration
