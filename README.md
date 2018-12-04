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

az deployment create --template-file azuredeploy.json --location eastus
