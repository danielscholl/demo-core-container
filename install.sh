#!/usr/bin/env bash
#
#  Purpose: Initialize the template load for testing purposes
#  Usage:
#    install.sh

###############################
## ARGUMENT INPUT            ##
###############################

usage() { echo "Usage: install.sh " 1>&2; exit 1; }

if [ -f ./.envrc ]; then source ./.envrc; fi

if [ -z $AZURE_LOCATION ]; then
  AZURE_LOCATION="eastus2"
fi

if [ -z $UNIQUE ]; then
  if [ $(uname -s)=="darwin" ]; then
    UNIQUE=$(jot -r 1 100 999)
  else
    UNIQUE=$(shuf -i 100-999 -n 1)
  fi
fi

BASE=${PWD##*/}
PRINCIPAL_NAME=${BASE}-Principal-${UNIQUE}

###############################
## FUNCTIONS                 ##
###############################

function CreateServicePrincipal() {
    # Required Argument $1 = PRINCIPAL_NAME

    if [ -z $1 ]; then
        tput setaf 1; echo 'ERROR: Argument $1 (PRINCIPAL_NAME) not received'; tput sgr0
        exit 1;
    fi

    if [[ $(az ad sp list --display-name $1 --query [].appId -otsv) == "" ]]; then
      CLIENT_SECRET=$(az ad sp create-for-rbac \
        --name "http://$1" \
        --skip-assignment \
        --query password -otsv)
      CLIENT_ID=$(az ad sp list \
        --display-name $1 \
        --query [].appId -otsv)
      OBJECT_ID=$(az ad sp list \
        --display-name $1 \
        --query [].objectId -otsv)
      USER_ID=$(az ad user show \
        --upn-or-object-id $(az account show --query user.name -otsv) \
        --query objectId -otsv)


      echo "" >> .envrc
      echo "export CLIENT_ID=${CLIENT_ID}" >> .envrc
      echo "export CLIENT_SECRET=${CLIENT_SECRET}" >> .envrc
      echo "export OBJECT_ID=${OBJECT_ID}" >> .envrc
      echo "export USER_ID=${USER_ID}" >> .envrc
      echo "export UNIQUE=${UNIQUE}" >> .envrc
    else
        tput setaf 3;  echo "Service Principal $1 already exists."; tput sgr0
        if [ -z $CLIENT_ID ]; then
          tput setaf 1; echo 'ERROR: Principal exists but CLIENT_ID not provided' ; tput sgr0
          exit 1;
        fi

        if [ -z $CLIENT_SECRET ]; then
          tput setaf 1; echo 'ERROR: Principal exists but CLIENT_SECRET not provided' ; tput sgr0
          exit 1;
        fi

        if [ -z $OBJECT_ID ]; then
          tput setaf 1; echo 'ERROR: Principal exists but OBJECT_ID not provided' ; tput sgr0
          exit 1;
        fi

        if [ -z $USER_ID ]; then
          tput setaf 1; echo 'ERROR: USER_ID not provided' ; tput sgr0
          exit 1;
        fi
    fi
}

###############################
## Azure Intialize           ##
###############################

tput setaf 2; echo 'Creating Service Principal...' ; tput sgr0
CreateServicePrincipal $PRINCIPAL_NAME

tput setaf 2; echo 'Deploying ARM Template...' ; tput sgr0
if [ -f ./params.json ]; then PARAMS="params.json"; else PARAMS="azuredeploy.parameters.json"; fi

az deployment create --template-file azuredeploy.json  \
  --location $AZURE_LOCATION \
  --parameters $PARAMS \
  --parameters random=$UNIQUE --parameters group="$BASE-$UNIQUE" \
  --parameters servicePrincipalClientId=$CLIENT_ID \
  --parameters servicePrincipalClientKey=$CLIENT_SECRET \
  --parameters servicePrincipalObjectId=$OBJECT_ID \
  --parameters userObjectId=$USER_ID

VAULT=$(az keyvault list --resource-group $BASE-$UNIQUE  -otable --query [].name -otsv)
REGISTRY=$(az acr list --resource-group $BASE-$UNIQUE --query [].name -otsv)

tput setaf 2; echo 'Adding Registry to Vault...' ; tput sgr0
az keyvault secret set --vault-name $VAULT --name containerRegistry --value $(az acr list --resource-group $BASE-$UNIQUE --query [].loginServer -otsv)

tput setaf 2; echo 'Building Docker Images...' ; tput sgr0
az acr login --name $REGISTRY
az acr run -r $REGISTRY -f build.yaml .

tput setaf 2; echo 'Deploying Container Instance...' ; tput sgr0
az container create \
    --resource-group $BASE-$UNIQUE \
    --name $BASE-$UNIQUE \
    --image $REGISTRY.azurecr.io/demo-core-container:latest \
    --registry-login-server $REGISTRY.azurecr.io \
    --registry-username $(az keyvault secret show --vault-name $VAULT --name clientId --query value -o tsv) \
    --registry-password $(az keyvault secret show --vault-name $VAULT --name clientSecret --query value -o tsv) \
    --dns-name-label $BASE-$UNIQUE \
    --query "{FQDN:ipAddress.fqdn}" \
    --output table
