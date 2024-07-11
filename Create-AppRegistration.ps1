param (
    [string]$orgName
)

# Create the app registration
$appName = "appreg-$orgName-pbi-mon-demo"
Write-Host "Creating app registration with name: $appName"
$app = az ad app create --display-name $appName --required-resource-accesses .\manifest.json | ConvertFrom-Json

# Generate a client secret
Write-Host "Generating client secret"
$clientSecret = az ad app credential reset --id $app.appId --query "password" -o tsv

# Output app details
$clientId = $app.appId
$tenantId = az account show --query "tenantId" -o tsv

Write-Host "App registration created successfully"
Write-Host "Client ID: $clientId"
Write-Host "Client Secret: $clientSecret"
Write-Host "Tenant ID: $tenantId"

# Return the details as an object
$details = [PSCustomObject]@{
    ClientId     = $clientId
    ClientSecret = $clientSecret
    TenantId     = $tenantId
    AppName      = $appName
}

return $details
