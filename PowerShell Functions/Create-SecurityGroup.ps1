param (
    [string]$orgName
)

$securityGroupName = "sg_${orgName}_pbi_mon_demo"
Write-Host "Creating security group '$securityGroupName'..."
$securityGroup = az ad group create --display-name $securityGroupName --mail-nickname $securityGroupName --query "id" -o tsv

# Check if the security group was created successfully
if (-not $securityGroup) {
    Write-Host "Failed to create the security group '$securityGroupName'. Exiting."
    exit 1
}

Write-Host "Security group '$securityGroupName' created successfully with ID: $securityGroup"


return $securityGroup