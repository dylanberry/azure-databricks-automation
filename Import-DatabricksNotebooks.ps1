param (
    [Parameter(Mandatory)]
    [string]$resourceGroup,

    [Parameter(Mandatory)]
    [string]$notebookPath,

    [string]$clientId,

    [string]$clientSecret,

    [string]$tenantId
)
# Setup

pip install databricks-cli

# Login

if ($tenantId) {
    az login --service-principal --allow-no-subscriptions --username $clientId --password $clientSecret --tenant $tenantId
} else {
    az login
}


# Get Databricks Access Token
$globalDatabricksResourceId = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"
$token = az account get-access-token --resource $globalDatabricksResourceId  | ConvertFrom-Json


# Cluster Creation
$databricksResource = az resource list --resource-group $resourceGroup --resource-type "Microsoft.Databricks/workspaces" | ConvertFrom-Json
$databricksWorkspace = az databricks workspace show --resource-group $resourceGroup --name $databricksResource.name | ConvertFrom-Json

$databricksInstanceUrl = "https://" + $databricksWorkspace.workspaceUrl
$env:DATABRICKS_AAD_TOKEN=$token.accessToken

$mavenCoordinates = Get-Content maven-packages.json | ConvertFrom-Json
#Install cluster libraries
foreach ($mavenCoordinate in $mavenCoordinates) {
    databricks libraries install --cluster-id $clusterId --maven-coordinates $mavenCoordinate
}

#Purge and Re-deploy Notebooks
databricks workspace rm -r /

# Deploy Notebooks
databricks workspace import_dir $notebookPath / -o