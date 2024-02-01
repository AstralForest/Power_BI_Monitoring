# Solution Prerequisites
- Azure subscription (with at least contributor role)
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
- **instance** can be any number, default is '0' you can leave it at that (it's in order to prevent conflicts in resource names)
- **client_name** abbreviation for your project (for example - Astral Forest = af). Use only lowercase letters! Whenever in the instruction you see &lt;instance&gt; or <client_name> fill it in with these values.
- **tenant_id** you could say it's your organization Azure ID, go to azure portal -> type 'Microsoft Entra ID' -> copy Tenant ID
- **region_uppercase** and **region** - region where your resources will be deployed, it's recommended to leave it as it is because some functionalities may not be available in all regions. If you wish to deploy solution in a different region please check wheter required resources are available there https://azure.microsoft.com/en-us/explore/global-infrastructure/products-by-region/ 
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
  
  b) **az group create -l northeurope -n <new_resource_group_name> --subscription <subscription_id>** - fill in your resource group name and subcription id (you can find available subscriptions in Command Line after az login - choose subcription where you have at least contributor role)
  
  c) **az deployment group create --resource-group <new_resource_group_name> --template-file .\serverless.bicep --parameters .\serverless.parameters.json --subscription <subscription_id>** fill in your resource group name (for example 'pbimon_myorg') and subcription id

- Open Azure Portal -> Resource Groups -> your newly created group -> 'Deployments' -> serverless -> after few minutes check whether deployment was successful

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/901daafb-e1bc-4c93-9a13-350079cade70)

- Don't close the terminal
  
3) The next step involves loading the database from the dacpac file (file format for databases).
- In terminal paste following command
  
**az storage blob upload --account-name stfunc<client_name>pbimon&lt;instance&gt; --container-name bacpac --name database --type block --file .\db-pbimon.bacpac --auth-mode login** fill in client_name and instance

- In your Resource Group open SQL Server resource (it will begin with server) -> 'Import database' (upper option menu) -> 'Select backup' -> Choose storage account beginnig with 'stfunc' -> 'bacpac' -> 'Select' -> database -> 'Database name' (enter: db-<client_name>-pbimon-&lt;instance&gt;) -> 'Authentication type' SQL Server'-> 'Server admin login' login_server_pbimon -> 'Password' (in another browser page go to your Resource Group Key Vault -> 'Secrets' -> 'secret-pbimon-server' -> 'Current Version' -> 'Copy secret value' -> paste) -> 'Pricing tier' allows you to configure your Database depending on your organization scale and needs (for most case we recommend Standard S0) -> 'OK'

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/907601c1-07c4-4593-b120-77c37000245f)

4) In the next step we are going to upload the function code and settings.
- Open Visual Studio Code -> 'File' -> 'Open folder' -> 'PBI Monitoring Functions'
- Open 'function_app.py' (left option menu) -> change vault_url address (replace client_name and instance) -> press 'Ctrl' + 'S'
  
![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/bd94108c-e418-49ed-8c23-f4e0e7d517c5)

- On left option menu click 'Extensions' (4 blocks icon) -> Type Azure Tools and install extension
- Click Terminal (upper option menu) -> 'New Terminal' -> In the terminal type 'az login' and log to your Azure account (if you receive error reopen VS Code)
- Click on Azure icon (left option menu, last icon) -> Click on little Function App icon -> 'Deploy to Function App' -> Choose your subcription and Funciton App -> In pop up click 'Deploy' (you may be prompted to sign to Azure first)

  ![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/c73f4d2a-7369-4d94-81d2-30c8e9055323)

5) Enable Cross-Origin Resource Sharing (it's a list of origins that can call your function)

   - Go to your Resource Group at Azure Portal -> Open Function App -> Scroll down left option menu -> 'CORS' ->  Add allowed origin https://portal.azure.com  -> 'Save'

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/852997ea-acf7-41fb-b6de-77e8ae18ad3b)

6) In this step we are going to publish Data Factory resources.
- At Azure Portal open your resource group and your Data Factory -> 'Launch studio' -> on left menu click on toolbox ('Manage') -> 'Git configuration' -> 'Configure' -> 'Repository type' select GitHub -> 'GitHub repository owner' type your GitHub nickname -> 'Continue' -> 'Use repository link' -> 'Git repository link' (open GitHub -> Repositories -> 'PowerBI_Monitoring' -> copy and paste browser link -> 'Collaboration branch' select main -> 'Root folder' /PBI Monitoring ADF/ -> 'Apply'
- 'Linked services' -> 'ls_kv' -> change 'Base URL' (replace client_name and instance) -> 'Save'
- 'ls_function' -> change 'Function App URL' (replace client_name and instance) -> 'Save'
   
![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/94e0c9d4-8395-4e07-9e49-cb5f32dc399d)

7) Test whether everything deployed successfully be running master pipeline
- Click on pencil icon 'Author' -> 'Publish' (upper option menu) -> 'Pipelines' -> 'Power BI Monitoring' -> 'Power BI Monitoring Master Pipeline Function' -> 'Debug'

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/e6535342-4fd2-4533-897f-90d859023cb6)



