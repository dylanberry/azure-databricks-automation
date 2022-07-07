# Configure Databricks Azure Key Vault-backed secret store
param (
    [Parameter(Mandatory)]
    [string]$resourceGroup,

    [string]$secretScopeName = "KeyVault"
)

Write-Host
#az login

Write-Host "Install Databricks CLI https://docs.databricks.com/dev-tools/cli/index.html requires Python + pip"
pip install databricks-cli

Write-Host "Install/update the extension databricks in az cli"
az extension add --name databricks
az extension add --upgrade -n databricks

$databricksResource = az resource list --resource-group $resourceGroup --resource-type "Microsoft.Databricks/workspaces" | ConvertFrom-Json
$databricksWorkspace = az databricks workspace show --resource-group $resourceGroup --name $databricksResource.name | ConvertFrom-Json

$globalDatabricksResourceId = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"
$token = az account get-access-token --resource $globalDatabricksResourceId | ConvertFrom-Json
$databricksInstanceUrl = "https://" + $databricksWorkspace.workspaceUrl
$env:DATABRICKS_AAD_TOKEN = $token.accessToken
databricks configure --aad-token --host $databricksInstanceUrl

$bearerToken = "Bearer " + $token.accessToken
$headers = @{
    Authorization = $bearerToken;
    Accept        = "application/scim+json"
}

$kvList = az resource list --resource-group $resourceGroup --resource-type "Microsoft.KeyVault/vaults" | ConvertFrom-Json
$kvResource = az resource show -g $resourceGroup -n $kvList.name --resource-type "Microsoft.KeyVault/vaults" | ConvertFrom-Json

$secretsUri = "$databricksInstanceUrl/api/2.0/secrets/scopes/create"

$json = '{
    "scope": "' + $secretScopeName + '",
    "scope_backend_type": "AZURE_KEYVAULT",
    "backend_azure_keyvault":
    {
        "resource_id": "' + $kvResource.id + '",
        "dns_name": "' + $kvResource.properties.vaultUri + '"
    },
    "initial_manage_principal": "users"
    }'
Invoke-RestMethod -Uri $secretsUri -Method POST -Headers $headers -Body $json -ContentType 'application/scim+json' -Verbose


$secretsListUri = "$databricksInstanceUrl/api/2.0/secrets/scopes/list"
Invoke-RestMethod -Uri $secretsListUri -Method GET -Headers $headers -Verbose