# Solution Prerequisites
- Azure subscription
- Power BI Administrator role
- [GitHub account](https://github.com/join)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

# Deployment process
Deployment process is almost fully automated and only requires manual intervention in places where the admin consent is required
The deployment process consists of following steps:

## 1) Clone repository to the local machine (~2 minutes)
1. Execute the following command in your PowerShell: `git clone https://github.com/AstralForest/Power_BI_Monitoring.git`
2. Enter newly created folder called "Power_BI_Monitoring"

## 2) Provision Azure environment (~15 minutes)
1. Execute the following command in PowerShell: `.\Provision-PBI-Monitoring-Demo.ps1`
2. Follow instructions of the script. It will require just the _**short name of the organization**_ (up to 5 letters) and the region where to provision it (you can press **Enter** to proceed with **northeurope**). All the rest is done automatically

> NOTE. Steps which are being executed by the script:
> 1. Provisions all Azure components
> 2. Copies database image to storage account and imports that into newly created database
> 3. Imports ADF resources into newly created Azure Data Factory instance
> 4. Creates **App Registration**, grants it privileges and creates Service Principal for it
> 5. Creates a **Security Group** and adds service principal to it
> 6. Provisions **PowerBI workspace**, deploys report and changes the connection string to a newly created database
> 7. Writes down essential variables to the configuration file "adf_config.json"

## 3) Allow **Security Group** to access Power BI API (**~2 minutes**)
1. Go to [Power BI Admin settings](https://app.powerbi.com/admin-portal/tenantSettings?experience=power-bi)
2. Add security group called "sg_{companyName}_pbi_mon_demo" to the following field:![image](https://github.com/user-attachments/assets/e0d7d913-bc89-438f-9b85-0ce7b4d314c4)
3. Click "Apply"

## 4) Verify if the admin consent is provided for the newly created App Registration (**~2 minutes**)
1. Go to [Portal App Registration](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade)
2. Find and click on app registration created as part of the automatic deployment process. It should be called "appreg-{companyName}-pbi-mon-demo" where the {companyName} is the 5 character string provided during deployment
3. Go to API permission to check whether all Configured permissions have status approved as shown on the picture below:![image](https://github.com/user-attachments/assets/ffc503da-7898-4380-88c7-1f519a827f36)
4. If the status is not Approved, ask your organization's administrator to "Grant Admin consent for {Company Name}". So to click here:![image](https://github.com/user-attachments/assets/37c6c0a9-9b63-47a2-9c93-b5f758570ca0)

## 5) Refresh data in PowerBI with the help of ADF job (**~10 minutes**)
1. Go back to the PowerShell inside the "Power_BI_Monitoring" folder cloned to the local machine
2. Execute the following command: `.\Trigger-ADF-Pipeline.ps1`
3. Wait until the script is executed till the end 
> NOTE. Script steps:
> 1. Triggers pipeline in newly created ADF instance called "**Power BI Monitoring Master Pipeline**"
> 2. Once the first pipeline finished it executes the second one called "**Load Power BI API Activity Events 30days**" to populate 30 days of history for the organization 

## 6) Update credentials in your Power BI report (**~3 minutes**)
1. Go to [Power BI Portal](https://app.powerbi.com/)
2. Click on Workspaces and select newly created "PBI_Demo_Workspace"
> ![image](https://github.com/user-attachments/assets/f921605f-9e15-42c9-a3ae-945e49322522)
3. Go to report's dataset settings
> ![image](https://github.com/user-attachments/assets/15b90c77-28e3-471b-8b3b-44426224bdb8)
4. Click on "Edit credentials"
> ![image](https://github.com/user-attachments/assets/211c1764-9687-4156-843c-0bdd0e41a900)
5. Select authentication "OAuth2" and click "Sign In"
> ![image](https://github.com/user-attachments/assets/ce2978e2-4707-4f3e-a952-3509cc40d454)
6. Select the account you were provisioning the environment with in the prompt window

## Final) Enjoy browsing your organization's Power BI statistics in one place! (~1 minute)
1. Go to [Power BI Portal](https://app.powerbi.com/)
2. Click on Workspaces and select newly created "PBI_Demo_Workspace"
> ![image](https://github.com/user-attachments/assets/f921605f-9e15-42c9-a3ae-945e49322522)
3. Refresh your Power BI dataset and once it is refreshed open the report
> ![image](https://github.com/user-attachments/assets/6bc9ce45-bd78-4c3d-ad9f-5dbac0c7872c)


# Additional information
## Naming conventions used when deploying resources:
**Resource Group**: rg-{companyName}-pbi
**Server Name**: server-{companyName}-pbimon-01
**Database Name**: db-{companyName}-pbimon-01
**Key Vault Name**: kv-{companyName}-pbimon-01
**Azure Data Factory**: adf-{companyName}-pbimon-01
**Storage Account**: st{companyName}pbimon01
**App Registration**: appreg-{companyName}-pbi-mon-demo
**Service Principal**: appreg-{companyName}-pbi-mon-demo
**Security Group**: sg_{companyName}_pbi_mon_demo
**Power BI Workspace**: PBI_Demo_Workspace
**Power BI Report**: PBI_Monitoring_Demo_2024
