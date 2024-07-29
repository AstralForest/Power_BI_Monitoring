param (
    [string]$orgName
)

$manifestFile = Join-Path -Path $PSScriptRoot -ChildPath "manifest.json"

# Create the app registration
$appName = "appreg-$orgName-pbi-mon-demo"
Write-Host "Creating app registration with name: $appName" -ForegroundColor Yellow
$app = az ad app create --display-name $appName --required-resource-accesses $manifestFile | ConvertFrom-Json

if ($app.appId -eq $null -or -not $app) {
    Write-Host "Failed to create app registration" -ForegroundColor Red
    exit 1
} else {
    Write-Host "App Registration has been provisioned" -ForegroundColor Green
}

# Generate a client secret
Write-Host "Generating client secret" -ForegroundColor Yellow
$clientSecret = az ad app credential reset --id $app.appId --query "password" -o tsv

if (-not $clientSecret) {
    Write-Host "Failed to generate client secret" -ForegroundColor Red
    exit 1
}else {
    Write-Host "Secret has been generated" -ForegroundColor Green
}

# Create the service principal
Write-Host "Creating service principal for app" -ForegroundColor Yellow
$sp = az ad sp create --id $app.appId | ConvertFrom-Json

if ($sp.id -eq $null -or -not $sp) {
    Write-Host "Failed to create service principal" -ForegroundColor Red
    exit 1
}else {
    Write-Host "Service Principal has been added to app" -ForegroundColor Green
}

# Output app details
$clientId = $app.appId
$tenantId = az account show --query "tenantId" -o tsv
$spObjectId = $sp.id

# Return the details as an object
$details = [PSCustomObject]@{
    ClientId     = $clientId
    ClientSecret = $clientSecret
    TenantId     = $tenantId
    AppName      = $appName
    SPObjectId   = $spObjectId
}

return $details
