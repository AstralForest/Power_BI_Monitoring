param (
    [string]$orgName
)

$securityGroupName = "sg_${orgName}_pbi_mon_demo"
Write-Host "Creating security group '$securityGroupName'..." -ForegroundColor Yellow
$securityGroup = az ad group create --display-name $securityGroupName --mail-nickname $securityGroupName --query "id" -o tsv

# Check if the security group was created successfully
if (-not $securityGroup) {
    Write-Host "Failed to create the security group '$securityGroupName'. Exiting." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Security group '$securityGroupName' has been created successfully." -ForegroundColor Green

}

return $securityGroup