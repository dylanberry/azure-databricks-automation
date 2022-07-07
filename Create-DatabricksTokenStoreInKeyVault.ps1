param (
    [Parameter(Mandatory)]
    [string]$resourceGroup,

    [Parameter(Mandatory)]
    [string]$kvName
)

az login

$databricksTokenSecretName = "databricksClusterKey"

az extension add --name databricks

# Get Databricks Access Token

$globalDatabricksResourceId = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"

$token = az account get-access-token --resource $globalDatabricksResourceId  | ConvertFrom-Json
# Get Databricks workspace

$databricksResource = az resource list --resource-group $resourceGroup --resource-type "Microsoft.Databricks/workspaces" | ConvertFrom-Json
$databricksWorkspace = az databricks workspace show --resource-group $resourceGroup --name $databricksResource.name | ConvertFrom-Json

$databricksInstanceUrl = "https://" + $databricksWorkspace.workspaceUrl
#$env:DATABRICKS_AAD_TOKEN=$token.accessToken
#databricks configure --aad-token --host $databricksInstanceUrl


# Create databricks token

$bearerToken = "Bearer " + $token.accessToken
$headers = @{
    Authorization = $bearerToken;
    Accept = "application/scim+json"
 }
$tokenUri = "$databricksInstanceUrl/api/2.0/token/create"

$body = @{
    comment = "Azure Data Factory"
}
$json = $body | ConvertTo-Json

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$databricksTokenResponse = Invoke-RestMethod -Uri $tokenUri -Method POST -Headers $headers -Body $json -ContentType 'application/scim+json' -Verbose


# Store token in Key Vault
az keyvault secret set --name $databricksTokenSecretName --vault-name $kvName --value $databricksTokenResponse.token_value