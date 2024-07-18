# Import the required module for PowerShell
Import-Module Az.DataFactory

# Path to the configuration file
$configFilePath = "adf_config.json"

# Read the configuration file
if (-not (Test-Path $configFilePath)) {
    Write-Host "Configuration file not found: $configFilePath"
    exit 1
}

$config = Get-Content -Path $configFilePath | ConvertFrom-Json

# Extract the ADF instance name, resource group name, and subscription ID from the config
$adfInstanceName = $config.ADFInstanceName
$resourceGroupName = $config.ResourceGroupName
$subscriptionId = $config.SubscriptionId

# Define the names of the ADF pipelines to trigger
$firstPipelineName = "Power BI Monitoring Master Pipeline"  # Replace with your actual first pipeline name
$secondPipelineName = "Load Power BI API Activity Events 30days"  # Replace with your actual second pipeline name

# Set the Azure subscription context
az account set --subscription $subscriptionId

# Function to get the access token
function Get-AccessToken {
    $tokenResponse = az account get-access-token --resource https://management.azure.com/ --query accessToken -o tsv
    return $tokenResponse
}

# Function to check pipeline run status using REST API
function Get-PipelineRunStatus {
    param (
        [string]$resourceGroupName,
        [string]$adfInstanceName,
        [string]$pipelineRunId
    )
    $accessToken = Get-AccessToken
    $url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DataFactory/factories/$adfInstanceName/pipelineruns/$pipelineRunId`?api-version=2018-06-01"
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers @{Authorization = "Bearer $accessToken"}
    return $response.status
}

# Function to trigger a pipeline using REST API
function Trigger-Pipeline {
    param (
        [string]$resourceGroupName,
        [string]$adfInstanceName,
        [string]$pipelineName
    )
    $accessToken = Get-AccessToken
    $url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DataFactory/factories/$adfInstanceName/pipelines/$pipelineName/createRun?api-version=2018-06-01"
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers @{Authorization = "Bearer $accessToken"}
    return $response.runId
}

# Trigger the first ADF pipeline
Write-Host "Triggering ADF pipeline '$firstPipelineName' in instance '$adfInstanceName'..."
$firstPipelineRunId = Trigger-Pipeline -resourceGroupName $resourceGroupName -adfInstanceName $adfInstanceName -pipelineName $firstPipelineName

if (-not $firstPipelineRunId) {
    Write-Host "Failed to initiate first pipeline run."
    exit 1
}

Write-Host "First pipeline run initiated successfully. Run ID: $firstPipelineRunId"

# Wait for the first pipeline run to finish
while ($true) {
    $status = Get-PipelineRunStatus -resourceGroupName $resourceGroupName -adfInstanceName $adfInstanceName -pipelineRunId $firstPipelineRunId
    Write-Host "First pipeline run status: $status"
    if ($status -eq "Succeeded") {
        Write-Host "First pipeline run succeeded."
        break
    } elseif ($status -eq "Failed" -or $status -eq "Cancelled") {
        Write-Host "First pipeline run failed or was cancelled."
        exit 1
    } else {
        Start-Sleep -Seconds 30
    }
}

# Trigger the second ADF pipeline
Write-Host "Triggering ADF pipeline '$secondPipelineName' in instance '$adfInstanceName'..."
$secondPipelineRunId = Trigger-Pipeline -resourceGroupName $resourceGroupName -adfInstanceName $adfInstanceName -pipelineName $secondPipelineName

if (-not $secondPipelineRunId) {
    Write-Host "Failed to initiate second pipeline run."
    exit 1
}

Write-Host "Second pipeline run initiated successfully. Run ID: $secondPipelineRunId"

# Wait for the second pipeline run to finish
while ($true) {
    $status = Get-PipelineRunStatus -resourceGroupName $resourceGroupName -adfInstanceName $adfInstanceName -pipelineRunId $secondPipelineRunId
    Write-Host "Second pipeline run status: $status"
    if ($status -eq "Succeeded") {
        Write-Host "Second pipeline run succeeded."
        break
    } elseif ($status -eq "Failed" -or $status -eq "Cancelled") {
        Write-Host "Second pipeline run failed or was cancelled."
        exit 1
    } else {
        Start-Sleep -Seconds 30
    }
}

Write-Host "Both pipeline runs completed successfully."