try {
    # Variables
    $workspaceName = "PBI_Auto_Deployment"
    $pbixFilePath = "PBI_Monitoring_Demo_2024.pbix"
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

Write-Host $report

    $datasourceConnectionDetailsJson = "{`"updateDetail`":[{`"connectionDetails`":{`"server`":`"server-astra-pbimon-02.database.windows.net`",`"database`":`"db-astra-pbimon-02`"}}]}"

    Invoke-RestMethod -Method Post `
            -Uri "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/datasets/$($dataset.Id)/Default.UpdateDatasources" `
            -Headers @{ Authorization = "Bearer $((Get-PowerBIAccessToken).AccessToken)" } `
            -Body $datasourceConnectionDetailsJson `
            -ContentType "application/json"

    Write-Output "Report and Dataset imported and parameters updated successfully."
} catch {
    Write-Error "An error occurred: $_"
}
