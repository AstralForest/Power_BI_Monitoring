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

# Function to prompt for the organization name
function Get-OrganizationName {
    param (
        [string]$promptMessage = "Please enter the organization name (up to 5 characters): "
    )
    
    while ($true) {
        $orgName = Read-Host $promptMessage
        if ($orgName.Length -le 5) {
            return $orgName
        } else {
            Write-Host "The organization name must be 5 characters or less. Please try again."
        }
    }
}

# Function to get available subscriptions and prompt user to select one
function Get-Subscription {
    Write-Host "Fetching available subscriptions..."
    $subscriptions = az account list --query "[].{Name:name, ID:id}" -o json | ConvertFrom-Json
    
    if (-not $subscriptions) {
        Write-Host "No subscriptions found. Exiting."
        exit
    }

    Write-Host "Available subscriptions:"
    $subscriptions | ForEach-Object { Write-Host "$($_.Name)" }

    $subscriptionName = Read-Host "Please enter the subscription name you want to use: "
    
    $selectedSubscription = $subscriptions | Where-Object { $_.Name -eq $subscriptionName }
    
    if (-not $selectedSubscription) {
        Write-Host "Invalid subscription name. Exiting."
        exit
    }
    
    $subscriptionId = $selectedSubscription.ID
    az account set --subscription $subscriptionId
    
    Write-Host "Selected subscription: $subscriptionName ($subscriptionId)"
    
    return $subscriptionId
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

# Get the organization name from the user
$orgName = Get-OrganizationName

# Get the resource group name based on the organization name
$resourceGroupName = "rg-$orgName-pbidemo-01"

# Get the subscription ID from the user
$subscriptionId = Get-Subscription

# Get the location from the user
$location = Get-Location

# Create the resource group using Azure CLI
Write-Host "Creating resource group '$resourceGroupName' in location '$location' under subscription '$subscriptionId'..."
az group create -l $location -n $resourceGroupName --subscription $subscriptionId

# Check if the resource group was created successfully
$resourceGroup = az group show --name $resourceGroupName --query "name" -o tsv

if (-not $resourceGroup) {
    Write-Host "Failed to create the resource group '$resourceGroupName'. Exiting."
    exit
}

Write-Host "Resource group '$resourceGroupName' created successfully."

# Call the script to create an app registration
Write-Host "Creating app registration..."
$appRegistrationDetails = & ".\PowerShell Functions\Create-AppRegistration.ps1" -orgName $orgName

Write-Host "Creating security group..."
$securityGroup = & ".\PowerShell Functions\Create-SecurityGroup.ps1" -orgName $orgName

# Add the service principal to the security group
$servicePrincipalId = $appRegistrationDetails.SPObjectId
Write-Host "Adding service principal with ID '$servicePrincipalId' to the security group '$securityGroupName'..."
az ad group member add --group $securityGroup --member-id $servicePrincipalId

Write-Host "Service principal added to the security group successfully."

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
Write-Host "Deploying Bicep template..."
az deployment group create --resource-group $resourceGroupName --template-file $bicepFile --parameters `
    instance="01" `
    client_name=$orgName `
    tenant_id=$tenantId `
    region=$location `
    app_reg_client=$clientId `
    app_reg_secret=$clientSecret `
    rg_owner_id=$rgOwnerId `
    server_admin_mail=$serverAdminMail 

Write-Host "Environment provisioning completed successfully."

# Upload the .bacpac file to the storage account
$storageAccountName = "st${orgName}pbimon01"
Write-Host "Uploading .bacpac file to the storage account '$storageAccountName'..."
az storage blob upload --account-name $storageAccountName --container-name bacpac --name database.bacpac --type block --file $bacpacFile --auth-mode login --overwrite true

Write-Host "Importing database into the SQL Server..."
$serverName = "server-${orgName}-pbimon-01"
$databaseName = "db-${orgName}-pbimon-01"
$dataFactoryName = "adf-${orgName}-pbimon-01"
$kvName = "kv-${orgName}-pbimon-01"
$adminLogin = "login_server_pbimon"
$serverPassword = az keyvault secret show --vault-name "kv-${orgName}-pbimon-01" --name "secret-pbimon-server" --query "value" -o tsv

# Construct the import command
$importCommand = ("az sql db import -g $resourceGroupName -s $serverName -n $databaseName --storage-key-type StorageAccessKey --storage-key", $(az storage account keys list --account-name $storageAccountName --query "[0].value" -o tsv), "--storage-uri `"https://${storageAccountName}.blob.core.windows.net/bacpac/database.bacpac`" --admin-user $adminLogin --admin-password $serverPassword") -join ' '

# Execute the import command
Invoke-Expression $importCommand

Write-Host "Database import initiated. You can monitor the progress in the Azure portal."

# define adf name

# Path to the ADF template and parameters files
$adfTemplateFile = "PBI Monitoring Published ADF/ARMTemplateForFactory.json"
$adfParametersFile = "PBI Monitoring Published ADF/ARMTemplateParametersForFactory.json"

# Deploy the ADF template using Azure CLI
Write-Host "Deploying ADF template..."
az deployment group create --resource-group $resourceGroupName --template-file $adfTemplateFile `
    --parameters $adfParametersFile `
    --parameters factoryName=$dataFactoryName `
                ls_kv_properties_typeProperties_baseUrl="https://$kvName.vault.azure.net/" `
                default_properties_token_url_value="https://login.microsoftonline.com/$tenantId/oauth2/token" `
                default_properties_kv_app_secret_url_value="https://$kvName.vault.azure.net/secrets/secret-pbimon-app-reg-secret/?api-version=7.0" `
                default_properties_app_client_id_value=$clientId

Write-Host "ADF deployment completed successfully."

Write-Host "Deploying PBI Report..."
$securityGroup = & ".\PowerShell Functions\Deploy-PBI-Report.ps1" -serverName $serverName -databaseName $databaseName


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

Write-Host "ADF instance name, resource group name, and subscription ID written to config file: $configFilePath"
