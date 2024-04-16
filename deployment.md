# Solution Prerequisites
- Azure subscription
- Power BI Administrator role
- [Visual Studio Code](https://code.visualstudio.com/download) (at least community edition)
- [GitHub account](https://github.com/join)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

# Deployment

1) First step is to create App Registration (technical user, an app representation that will be making API requests) with access to both Graph and Power BI API.
- Open [Azure portal](https://portal.azure.com/) -> type 'app registrations' in search panel -> select 'New registration' -> fill registration name (for example 'AR_PBI_Monitoring') -> Select 'Accounts in this organizational directory only (Single tenant)' -> Click 'Register'
- In your newly create App Registration select 'API permissions' (left-side menu) -> 'Add a permission' -> 'Microsoft Graph' -> 'Application permissions' -> type 'Group.Read.All' and 'User.Read.All' select them both -> 'Add permissions'
- Go to 'Certificates & secrets' -> 'New client secret' -> Copy newly created secret and save it somewhere
  
  If you receive the same Status as in the screenshot below ask your Azure Adminstrator to approve consent for the application.
  
![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/f64d184d-0675-4f00-899f-a80468fc68b9)

 - Next follow Microsoft documentation on enabling your Registration for read-only admin APIs. Start from step 2 (we have already created Microsoft Entra app it's another word for App Registration). https://learn.microsoft.com/lb-lu/power-bi/enterprise/read-only-apis-service-principal-authentication
2) Fork the project -> you will be able to modify the files accoriding to your needs
   
 ![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/8128e115-48db-450f-971d-9d9e7add6241)

3) The next step is to deploy bicep template to Azure. Bicep is declarative language for creating and deploying Azure resources.
- Download project files to your local disk -> Open project on GitHub -> 'Code' -> 'Download as Zip' -> Right click on zip file -> 'Extract all'
Open folder 'PBI Monitoring Infrastructure' -> right click on file serverless.parameters.json -> 'Edit with Notepad' (or any other text editor) -> modify following parameters in json:
- **instance** can be any number, default is '0' you can leave it at that (it's in order to prevent conflicts in resource names - it's necessary to fill this parameter)
- **client_name** abbreviation for your project (for example - Astral Forest = af). Use only lowercase letters! Whenever in the instruction you see &lt;instance&gt; or <client_name> fill it in with these values.
- **tenant_id** you could say it's your organization Azure ID, go to azure portal -> type 'Microsoft Entra ID' -> copy Tenant ID
- **region** - region where your resources will be deployed, it's recommended to leave it as it is because some functionalities may not be available in all regions. If you wish to deploy solution in a different region please check wheter required resources are available there https://azure.microsoft.com/en-us/explore/global-infrastructure/products-by-region/ 
- **rg_owner_id** at Microsoft Entra search your last name -> open your profile -> copy object id
- **server_admin_mail** your organization mail
- **admin_sid** same value as in rg_owner_id
- **app_reg_client** open App Registration which you created -> copy value under 'Application (client) ID' 
- **app_reg_secret** paste the secret you copied during creation of App Registration. If you forgot to do so just create new secret and copy its value.

- Save all the changes -> 'Ctrl' + 'S'

- In the same folder click on the path and type 'cmd' -> press enter
![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/6dffd4f8-0cd4-4dc2-acbd-83cf57dbff4e)

- In the Command Line paste following commands
  
  a) **az login** -> you should be redirected to Azure login page -> log in -> close page and come back to Command Line
  
  b) **az group create -l northeurope -n <new_resource_group_name> --subscription <subscription_id>** - This command creates Resoruce Group for your solution. Fill in your Resource Group name and subcription id (you can find available subscriptions in Command Line after az login - choose subcription where you have at least contributor role)
  
  c) **az deployment group create --resource-group <new_resource_group_name> --template-file .\serverless.bicep --parameters .\serverless.parameters.json --subscription <subscription_id>** fill in your resource group name (for example 'pbimon_myorg') and subcription id

- Open Azure Portal -> Resource Groups -> your newly created group -> 'Deployments' -> serverless -> after few minutes check whether deployment was successful

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/901daafb-e1bc-4c93-9a13-350079cade70)

- Don't close the terminal
  
3) The next step involves loading the database from the bacpac file (file format for databases).
- In terminal paste following command
  
**az storage blob upload --account-name stfunc<client_name>pbimon&lt;instance&gt; --container-name bacpac --name database --type block --file .\database.bacpac --auth-mode login** fill in client_name and instance

- In your Resource Group open SQL Server resource (it will begin with server) -> 'Import database' (upper option menu) -> 'Select backup' -> Choose storage account beginnig with 'stfunc' -> 'bacpac' -> 'Select' -> database -> 'Database name' (enter: db-<client_name>-pbimon-&lt;instance&gt;) -> 'Authentication type' SQL Server'-> 'Server admin login' login_server_pbimon -> 'Password' (in another browser page go to your Resource Group Key Vault -> 'Secrets' -> 'secret-pbimon-server' -> 'Current Version' -> 'Copy secret value' -> paste) -> 'Pricing tier' allows you to configure your Database depending on your organization scale and needs (for most case we recommend Standard S0) -> 'OK'

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/907601c1-07c4-4593-b120-77c37000245f)

5) In this step we are going to publish Data Factory resources.
- At Azure Portal open your resource group and your Data Factory -> 'Launch studio' -> on left menu click on toolbox ('Manage') -> 'Git configuration' -> 'Configure' -> 'Repository type' select GitHub -> 'GitHub repository owner' type your GitHub nickname -> 'Continue' -> 'Use repository link' -> 'Git repository link' (open GitHub -> Repositories -> 'PowerBI_Monitoring' -> copy and paste browser link -> 'Collaboration branch' select main -> 'Root folder' /PBI Monitoring ADF/ -> 'Apply'
- 'Linked services' -> 'ls_kv' -> change 'Base URL' (replace client_name and instance) -> 'Save'
   
![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/29d03429-0774-40ff-837f-b6ed19781f83)

- 'Global parameters' -> fill values in {} -> **token_url**; **kv_app_secret_url**; **app_client_id** (these are same values which you have filled in in step 3)
  
 ![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/3ef46935-7397-460e-9f56-760e3e3cea0a)


6) Test whether everything deployed successfully be running master pipeline
- Click on pencil icon 'Author' -> 'Publish' (upper option menu) -> 'Pipelines' -> 'Power BI Monitoring' -> 'Power BI Monitoring Master Pipeline' -> 'Debug'

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/34a502ea-91e0-4130-a11c-b1e369850747)

7) To use PBI Monitoring report follow belows steps:
- Download current version of the pbit file (for exmaple PBI_Monitoring_open_source_template_03_2024.pbit)
- Open it file in Power BI Desktop
- Fill parameters with your metadata information
![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/161041983/35b505cb-61f1-45ca-b360-03f798397cca)
- Press "Load" button
- Press "Publish" button
- Select workspace name where you want to publish the report
![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/161041983/cc57b4b6-834c-43b2-98c6-0b14489bb726)
- Press "Select" button
- After a while you will receive information about the successful publication of the report
![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/161041983/610967b4-626e-4159-80b6-be190ccf9824)
- Now you can see published report in PBI Service
![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/161041983/d91597d3-9bb2-4135-88a6-01b345637c3b)

