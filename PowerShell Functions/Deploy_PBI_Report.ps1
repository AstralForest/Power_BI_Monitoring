param (
    [string]$serverName,
    [string]$databaseName
)

try {
    # Variables
    $workspaceName = "PBI_Demo_Workspace"
    $pbixFilePath = "..\PBI Monitoring Report\PBI_Monitoring_Demo_2024.pbix"
    $reportName = "PBI_Monitoring_Demo_2024"

    # Authenticate
    Connect-PowerBIServiceAccount

    $workspace = Get-PowerBIWorkspace -Name $workspaceName

    if($workspace)
    {
        Write-Host "The workspace named $workspaceName already exists."
    }
    else
    {
        Write-Host "Creating new workspace named $workspaceName..."
        $workspace = New-PowerBIWorkspace -Name $workspaceName
    }

    $workspaceId = $workspace.Id
    New-PowerBIReport -Path $pbixFilePath -Workspace $workspace -ConflictAction CreateOrOverwrite

    # Get the imported report and dataset details
    $report = Get-PowerBIReport -WorkspaceId $workspaceId | Where-Object { $_.Name -eq $reportName }
    $dataset = Get-PowerBIDataset -WorkspaceId $workspaceId | Where-Object { $_.Id -eq $report.DatasetId }

    $datasourceConnectionDetailsJson = "{`"updateDetails`":[{`"connectionDetails`":{`"server`":`"$serverName`",`"database`":`"$databaseName`"}}]}"

    Invoke-PowerBIRestMethod -Method Post `
            -url "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/datasets/$($dataset.Id)/Default.UpdateDatasources" `
            -Body $datasourceConnectionDetailsJson `

    Write-Output "Report and Dataset imported and parameters updated successfully."
} catch {
    Write-Error "An error occurred: $_"
}
