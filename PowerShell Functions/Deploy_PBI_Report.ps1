param (
    [string]$serverName,
    [string]$databaseName
)

try {
    # Variables
    $workspaceName = "PBI_Demo_Workspace"
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $pbixFilePath = Join-Path $scriptDir "..\PBI Monitoring Report\PBI_Monitoring_Demo_2024.pbix"
    $reportName = "PBI_Monitoring_Demo_2024"

    Write-Host $pbixFilePath

    try {
        # Try to get the Power BI access token
        Get-PowerBIAccessToken > $null
        Write-Host "User is already logged in to Power BI."
    }
    catch {
        # If an error occurs, prompt the user to log in
        Write-Host "User is not logged in to Power BI. Prompting for login..."
        Connect-PowerBIServiceAccount > $null
        # Verify login was successful
        try {
            Get-PowerBIAccessToken > $null
            Write-Host "Login successful."
        }
        catch {
            Write-Host "Login failed. Exiting script."
            exit 1
        }
    }
    

    $workspace = Get-PowerBIWorkspace -Name $workspaceName

    if($workspace)
    {
        Write-Host "The workspace named $workspaceName already exists."
    }
    else
    {
        Write-Host "Creating new workspace named $workspaceName..."
        $workspace = New-PowerBIWorkspace -Name $workspaceName > $null
        Write-Host "Workspace has been created successfully"
    }

    $workspaceId = $workspace.Id
    New-PowerBIReport -Path $pbixFilePath -Workspace $workspace -ConflictAction CreateOrOverwrite > $null

    # Get the imported report and dataset details
    $report = Get-PowerBIReport -WorkspaceId $workspaceId | Where-Object { $_.Name -eq $reportName }
    $dataset = Get-PowerBIDataset -WorkspaceId $workspaceId | Where-Object { $_.Id -eq $report.DatasetId }

    $datasourceConnectionDetailsJson = "{`"updateDetails`":[{`"connectionDetails`":{`"server`":`"$serverName.database.windows.net`",`"database`":`"$databaseName`"}}]}"

    Invoke-PowerBIRestMethod -Method Post `
            -url "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/datasets/$($dataset.Id)/Default.UpdateDatasources" `
            -Body $datasourceConnectionDetailsJson `

    Write-Output "Report and Dataset imported and parameters updated successfully."
} catch {
    Write-Error "An error occurred: $_"
}
