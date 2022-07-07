#Grant Service Principal Admin Access to Databricks
param (
    [Parameter(Mandatory)]
    [string]$resourceGroup,

    [Parameter(Mandatory)]
    [string]$spnObjectId
)

az login

$databricksResource = az resource list --resource-group $resourceGroup --resource-type "Microsoft.Databricks/workspaces" | ConvertFrom-Json
$databricksWorkspace = az databricks workspace show --resource-group $resourceGroup --name $databricksResource.name | ConvertFrom-Json

$globalDatabricksResourceId = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"
$token = az account get-access-token --resource $globalDatabricksResourceId | ConvertFrom-Json
$databricksInstanceUrl = "https://" + $databricksWorkspace.workspaceUrl
#$env:DATABRICKS_AAD_TOKEN=$token.accessToken
#databricks configure --aad-token --host $databricksInstanceUrl

$bearerToken = "Bearer " + $token.accessToken
$headers = @{
    Authorization = $bearerToken;
    Accept = "application/scim+json"
 }
$groupsUri = "$databricksInstanceUrl/api/2.0/preview/scim/v2/Groups?filter=displayName+sw+admins"

$groups = Invoke-RestMethod -Uri $groupsUri -Method GET -Headers $headers -Verbose

$spnRecord = $groups.Resources.members | ? display -eq $spnObjectId
$spnUri = "$databricksInstanceUrl/api/2.0/preview/scim/v2/ServicePrincipals"

if (-not $spnRecord)
{
    $body = @{
        schemas = @("urn:ietf:params:scim:schemas:core:2.0:ServicePrincipal")
        applicationId = $spnObjectId
        displayName = $spnObjectId
        groups = @(
        @{
            value = $groups.Resources.id
        }
        )
        entitlements = @(
        @{
            value = "allow-cluster-create"
        }
        )
    }
    $json = $body | ConvertTo-Json
    Invoke-RestMethod -Uri $spnUri -Method POST -Headers $headers -Body $json -ContentType 'application/scim+json' -Verbose

    #databricks groups add-member --parent-name "admins" --user-name $spnObjectId
}
Invoke-RestMethod -Uri $spnUri -Method GET -Headers $headers -ContentType 'application/scim+json' -Verbose
