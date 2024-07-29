# Function to prompt for the organization name
function Get-OrganizationName {
    param (
        [string]$promptMessage = "Please enter the organization name (up to 7 characters): "
    )
    
    while ($true) {
        $orgName = Read-Host $promptMessage
        if ($orgName.Length -le 7) {
            return $orgName.ToLower()
        } else {
            Write-Host "The organization name must be 7 characters or less. Please try again."
        }
    }
}

# Function to prompt for the location
function Get-Location {
    param (
        [string]$defaultLocation = "northeurope"
    )
    
    $location = Read-Host "Please enter the location to provision the resource group (default: $defaultLocation): "
    
    if (-not $location) {
        $location = $defaultLocation
    }
    
    return $location
}

$esc = [char]27
$green = "${esc}[32m"
$red = "${esc}[31m"
$reset = "${esc}[0m"
function Output-ComponentStatus {
    param (
        [string]$componentName,
        [bool]$componentValue
    )
    $color = if ($componentValue) { $green } else { $red }
    Write-Host "${componentName}: ${color}$componentValue${reset}"
}

function Output-AllStatuses {
    Output-ComponentStatus -componentName "Resource Group Provisioned" -componentValue $rgProvisioned
    Output-ComponentStatus -componentName "App Registration Provisioned" -componentValue $appRegProvisioned
    Output-ComponentStatus -componentName "Security Group Provisioned" -componentValue $sgProvisioned
    Output-ComponentStatus -componentName "App Registration Added to Security Group" -componentValue $appRegAddedToSg
    Output-ComponentStatus -componentName "Bicep Deployed" -componentValue $bicepDeployed
    Output-ComponentStatus -componentName "Dacpac uploaded to Storage Account" -componentValue $dacpacUploadedToSA
    Output-ComponentStatus -componentName "Database Image Deployed" -componentValue $dbImageDeployed
    Output-ComponentStatus -componentName "ADF Deployed" -componentValue $adfDeployed
    Output-ComponentStatus -componentName "Workspace Created" -componentValue $workspaceCreated
    Output-ComponentStatus -componentName "PBIX Deployed" -componentValue $pbixDeployed
    Output-ComponentStatus -componentName "Connection String Changed" -componentValue $connStrChanged
}

$rgProvisioned = $false
$appRegProvisioned = $false
$sgProvisioned = $false
$appRegAddedToSg = $false
$bicepDeployed = $false
$dacpacUploadedToSA = $false
$adfDeployed = $false
$dbImageDeployed = $false
$workspaceCreated = $false
$pbixDeployed = $false
$connStrChanged = $false

# Ensure Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli and then re-run this script."
    exit 1
}
# Check if the MicrosoftPowerBIMgmt module is installed
if (-not (Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt)) {
    Write-Host "MicrosoftPowerBIMgmt module is not installed. Installing..."
    try {
        Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force -AllowClobber
        Write-Host "MicrosoftPowerBIMgmt module installed successfully."
    } catch {
        Write-Host "Failed to install MicrosoftPowerBIMgmt module. Please check your permissions or internet connection."
        exit 1
    }
}
Import-Module MicrosoftPowerBIMgmt -ErrorAction Stop



# Prompt the user to log in to Azure
Write-Host "Please log in to your Azure account."
az login
Write-Host "Please select the account for the Power BI Service."
Connect-PowerBIServiceAccount > $null

# Get the organization name from the user
$orgName = Get-OrganizationName

# Get the resource group name based on the organization name
$resourceGroupName = "rg-$orgName-pbidemo-01"

# Get the subscription ID from the user
$subscriptionId = az account show --query id --output tsv

# Get the location from the user
$location = Get-Location

# Create the resource group using Azure CLI
Write-Host "Creating resource group '$resourceGroupName' in location '$location' under subscription '$subscriptionId'..." -ForegroundColor Yellow
az group create -l $location -n $resourceGroupName --subscription $subscriptionId > $null

# Check if the resource group was created successfully
$resourceGroup = az group show --name $resourceGroupName --query "name" -o tsv

if (-not $resourceGroup) {
    Write-Host "Failed to create the resource group '$resourceGroupName'. Exiting." -ForegroundColor Red
    $rgProvisioned = $false
    Output-AllStatuses
    exit
} else {
    Write-Host "Resource group '$resourceGroupName' created successfully." -ForegroundColor Green
    $rgProvisioned = $true
}


# Call the script to create an app registration
Write-Host "Creating app registration..." -ForegroundColor Yellow
$appRegistrationDetails = & ".\PowerShell Functions\Create-AppRegistration.ps1" -orgName $orgName

if (-not $appRegistrationDetails) {
    Write-Host "Failed to create app registration" -ForegroundColor Red
} else {
    Write-Host "Successfully created app registration" -ForegroundColor Green
    $appRegProvisioned = $true
}

if ($appRegProvisioned) {
    Write-Host "Creating security group..." -ForegroundColor Yellow
    $securityGroup = & ".\PowerShell Functions\Create-SecurityGroup.ps1" -orgName $orgName

    if (-not $securityGroup) {
        Write-Host "Failed to create security group" -ForegroundColor Red
        $sgProvisioned = $false
    } else {
        Write-Host "Security Group has been provisioned" -ForegroundColor Green
        $sgProvisioned = $true
    }
}

if ($appRegProvisioned -and $sgProvisioned) {
    # Add the service principal to the security group
    $servicePrincipalId = $appRegistrationDetails.SPObjectId
    Write-Host "Adding service principal with ID '$servicePrincipalId' to the security group '$securityGroupName'..." -ForegroundColor Yellow
    az ad group member add --group $securityGroup --member-id $servicePrincipalId

    if ($LASTEXITCODE -ne 0) {
        Write-Host "It was not possible to add Service Principal to Security Group." -ForegroundColor Red
        $appRegAddedToSg = $false
    } else {
        Write-Host "Service principal added to the security group successfully." -ForegroundColor Green
        $appRegAddedToSg = $true
    }
} else {
    Write-Host "App Registration is not added to security group because either Security Group has not been provisioned or App Registration not registered"  -ForegroundColor Red
}


# Get the object ID of the user running the script
$rgOwnerId = az ad signed-in-user show --query "id" -o tsv

# Get the email of the user running the script
$serverAdminMail = az ad signed-in-user show --query "mail" -o tsv

# Path to the Bicep file
$bicepFile = ".\PBI Monitoring Infrastructure\serverless.bicep"
$bacpacFile = ".\PBI Monitoring Infrastructure\database.bacpac"

$tenantId = $appRegistrationDetails.TenantId
$clientId = $appRegistrationDetails.ClientId
$clientSecret = $appRegistrationDetails.ClientSecret

# Deploy the Bicep file using Azure CLI with individual parameters
Write-Host "Deploying Bicep template..."-ForegroundColor Yellow
az deployment group create --resource-group $resourceGroupName --template-file $bicepFile --parameters `
    instance="01" `
    client_name=$orgName `
    tenant_id=$tenantId `
    region=$location `
    app_reg_client=$clientId `
    app_reg_secret=$clientSecret `
    rg_owner_id=$rgOwnerId `
    server_admin_mail=$serverAdminMail > $null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Environment provisioning failed." -ForegroundColor Red
    $bicepDeployed = $false
    Output-AllStatuses
    exit 1
} else {
    Write-Host "Environment provisioning completed successfully." -ForegroundColor Green
    $bicepDeployed = $true
}

# Upload the .bacpac file to the storage account
$storageAccountName = "st${orgName}pbimon01"
Write-Host "Uploading .bacpac file to the storage account '$storageAccountName'..." -ForegroundColor Yellow
az storage blob upload --account-name $storageAccountName --container-name bacpac --name database.bacpac --type block --file $bacpacFile --auth-mode login --overwrite true > $null

if ($LASTEXITCODE -ne 0) {
    Write-Host "DACPAC was not uploaded to Storage Account." -ForegroundColor Red
    $dacpacUploadedToSA = $false
} else {
    Write-Host "DACPAC was successfully imported to Storage Account." -ForegroundColor Green
    $dacpacUploadedToSA = $true
}

Write-Host "Importing database into the SQL Server..." -ForegroundColor Yellow
$serverName = "server-${orgName}-pbimon-01"
$databaseName = "db-${orgName}-pbimon-01"
$dataFactoryName = "adf-${orgName}-pbimon-01"
$kvName = "kv-${orgName}-pbimon-01"
$adminLogin = "login_server_pbimon"
$serverPassword = az keyvault secret show --vault-name "kv-${orgName}-pbimon-01" --name "secret-pbimon-server" --query "value" -o tsv

if ($dacpacUploadedToSA) {
    # Construct the import command
    $importCommand = ("az sql db import -g $resourceGroupName -s $serverName -n $databaseName --storage-key-type StorageAccessKey --storage-key", $(az storage account keys list --account-name $storageAccountName --query "[0].value" -o tsv), "--storage-uri `"https://${storageAccountName}.blob.core.windows.net/bacpac/database.bacpac`" --admin-user $adminLogin --admin-password $serverPassword") -join ' '
    # Execute the import command
    Invoke-Expression $importCommand
    $dbImageDeployed = $true
    Write-Host "Database import is finished sucessfully" -ForegroundColor Green
} else {
    Write-Host "Database import step is skipped since dacpac was not uploaded to the Storage Account." -ForegroundColor Red
    $dbImageDeployed = $false
}

# Path to the ADF template and parameters files
$adfTemplateFile = "PBI Monitoring Published ADF/ARMTemplateForFactory.json"
$adfParametersFile = "PBI Monitoring Published ADF/ARMTemplateParametersForFactory.json"

if ($bicepDeployed -and $dacpacUploadedToSA) {
    # Deploy the ADF template using Azure CLI
    Write-Host "Deploying ADF template..." -ForegroundColor Yellow
    az deployment group create --resource-group $resourceGroupName --template-file $adfTemplateFile `
        --parameters $adfParametersFile `
        --parameters factoryName=$dataFactoryName `
                    ls_kv_properties_typeProperties_baseUrl="https://$kvName.vault.azure.net/" `
                    default_properties_token_url_value="https://login.microsoftonline.com/$tenantId/oauth2/token" `
                    default_properties_kv_app_secret_url_value="https://$kvName.vault.azure.net/secrets/secret-pbimon-app-reg-secret/?api-version=7.0" `
                    default_properties_app_client_id_value=$clientId
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ADF deployment failed." -ForegroundColor Red
        $adfDeployed = $false
    } else {
        Write-Host "ADF deployment completed successfully." -ForegroundColor Green
        $adfDeployed = $true
    }
}



Write-Host "Deploying PBI Report..." -ForegroundColor Yellow
& ".\PowerShell Functions\Deploy-PBI-Report.ps1" -serverName $serverName -databaseName $databaseName

# Write the ADF instance name, resource group name, and subscription ID to a configuration file
$configFilePath = "adf_config.json"

# Create a config object
$config = @{
    ADFInstanceName = $dataFactoryName
    ResourceGroupName = $resourceGroupName
    SubscriptionId = $subscriptionId
}

# Convert the config object to JSON and write it to a file
$config | ConvertTo-Json | Out-File -FilePath $configFilePath -Force

Write-Host "ADF instance name, resource group name, and subscription ID written to config file: $configFilePath" -ForegroundColor Yellow

Output-AllStatuses