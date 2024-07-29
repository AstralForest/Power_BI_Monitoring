param (
    [string]$orgName
)

$manifestFile = Join-Path -Path $PSScriptRoot -ChildPath "manifest.json"

# Create the app registration
$appName = "appreg-$orgName-pbi-mon-demo"
Write-Host "Creating app registration with name: $appName"
$app = az ad app create --display-name $appName --required-resource-accesses $manifestFile | ConvertFrom-Json

if ($app.appId -eq $null -or -not $app) {
    Write-Host "Failed to create app registration" -ForegroundColor Red
    exit 1
}

# Generate a client secret
Write-Host "Generating client secret"
$clientSecret = az ad app credential reset --id $app.appId --query "password" -o tsv

if (-not $clientSecret) {
    Write-Host "Failed to generate client secret" -ForegroundColor Red
    exit 1
}

# Create the service principal
Write-Host "Creating service principal for app"
$sp = az ad sp create --id $app.appId | ConvertFrom-Json

if ($sp.id -eq $null -or -not $sp) {
    Write-Host "Failed to create service principal" -ForegroundColor Red
    exit 1
}

# Output app details
$clientId = $app.appId
$tenantId = az account show --query "tenantId" -o tsv
$spObjectId = $sp.id

Write-Host "App registration created successfully"
Write-Host "Client ID: $clientId"
Write-Host "Client Secret: $clientSecret"
Write-Host "Tenant ID: $tenantId"
Write-Host "Service Principal Object ID: $spObjectId"

# Return the details as an object
$details = [PSCustomObject]@{
    ClientId     = $clientId
    ClientSecret = $clientSecret
    TenantId     = $tenantId
    AppName      = $appName
    SPObjectId   = $spObjectId
}

return $details
