
# Ensure Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli and then re-run this script."
    exit 1
}

# Prompt the user to log in to Azure
Write-Host "Please log in to your Azure account."
az login

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

# Function to prompt for the resource group name
function Get-ResourceGroupName {
    param (
        [string]$orgName
    )
    
    return "rg-$orgName-pbidemo-01"
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
$resourceGroupName = Get-ResourceGroupName -orgName $orgName

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
$appRegistrationDetails = & .\Create-AppRegistration.ps1 -orgName $orgName

Write-Host "App registration created successfully with details:"
Write-Host $appRegistrationDetails

Write-Host "Demo provisioning script completed successfully."
