param (
    [Parameter(Mandatory)]
    [string]$resourceGroup,

    [Parameter(Mandatory)]
    [string]$clusterDefinitionFilePath,

    [string]$clientId,

    [string]$clientSecret,

    [string]$tenantId
)

#Install Databricks CLI https://docs.databricks.com/dev-tools/cli/index.html (needs Python installed)
pip install databricks-cli

Write-Host "Install/update the extension databricks in az cli"
az extension add --name databricks
az extension add --upgrade -n databricks

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
databricks configure --aad-token --host $databricksInstanceUrl

$clusters = databricks clusters list
if ([string]::IsNullOrWhiteSpace($clusters)) {
    $newCluster = databricks clusters create --json-file "$(Pipeline.Workspace)/$databricksconfig/databricks-cluster.json" | ConvertFrom-Json
    $clusterId = $newCluster.cluster_id
} else {
    $clusterList = $clusters.Split(" ") | ? {-not [string]::IsNullOrWhiteSpace($_)}
    $clusterId = $clusterList[0]
}


$rawClusterInfo = databricks clusters get --cluster-id $clusterId
$clusterState = ""
if (-not ($rawClusterInfo -like "Error*")) {
    $clusterInfo = $rawClusterInfo | ConvertFrom-Json
    $clusterState = $clusterInfo.State
}

if ($clusterState -ne "RUNNING") {
    # Start the cluster
    databricks clusters start --cluster-id $clusterId
}


$maxRetryAttempts = 150
$retryCount = 0
$delayInMilliseconds = 50*60

do {
    $retryCount++

    $rawClusterInfo = databricks clusters get --cluster-id $clusterId

    try {

      if (-not ($rawClusterInfo -like "Error*" )) {
          $clusterInfo = $rawClusterInfo | ConvertFrom-Json
      }
      
      $clusterState = $clusterInfo.State
      if ($clusterState -eq "RUNNING") { 
          Write-Host "Cluster State $clusterState"
          break
      }

      Start-Sleep -Milliseconds $delayInMilliseconds
      Write-Host "Cluster State $clusterState"
    }
    catch {
      Write-Error $_.Exception.InnerException.Message -ErrorAction Continue
      
      Write-Host "Retry in $delayInMilliseconds"
      Start-Sleep -Milliseconds $delayInMilliseconds
    }
} while ($retryCount -lt $maxRetryAttempts)
  if ($clusterState -ne "RUNNING") { 
      Write-Host "Cluster State $clusterState"
      Exit 1
  }