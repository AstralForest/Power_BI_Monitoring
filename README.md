## Project Origin
While working with clients, we encountered growing need for monitoring and managing Power BI Service. To address this need, we have developed a comprehensive solution that covers the following aspects:
- Listing most active users and reports across all Power BI Tenant
- Tracking new reports deployment
- Maintaining order in Power BI Service by identifying unused or rarely used reports -> potential archival 
- Monitoring number of users and their activities
- Listing all the users using a given report
- Listing all the reports used by a given user
- Identifying Business Owners of the reports
- Usage History > 30 days
- potentially: listing all of the dowloaded reports
  
Full version: 
- Monitoring the assignment and usage of Power BI licenses
- Control the security of the reports and the access rights (across the tenant)
- Control of the RLS across all semantic models
- Control of the tenant settings
- Object Lineage: Data Source, Semantic Model, Table, Report

  
The end result is a Power BI report enabling you to monitor mentioned metrics:

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/484bcea1-6651-4e78-b755-14ba44fcfcbf)

**Please note that this is open-source version which does not include all mentioned above functionalities. In order to get the full solution, please contact: info@astralforest.com.**

## Project Description
Project leverages Power BI and Graph API queries to fetch data from Power BI Service. APIs are interfaces that allow programmatically access and interact with data from different platforms (in this case - Azure, Power BI Portal). Subsequently, the data is loaded to Azure SQL Database through Azure Data Factory — a cloud-based service designed for orchestrating and automating the data movement from different sources to various destinations. In the Azure SQL Database, the data undergoes processing and transformation into Facts and Dimensions where it serves as the foundation for generating a comprehensive Power BI Monitoring report.

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/5468da80-8df2-4998-b0cf-42a01ee9fabe)

Copy Activity makes API calls, processes the data and saves it directly to SQL Database.

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/129027cf-475d-41a8-8f6e-17243db1c787)

Database consists of 4 schemas:
- Bronze: Initial stage containing unprocessed raw data.
- Silver: Intermediate layer for data processing and transformation.
- Gold: Final stage with fully cleansed and report-oriented data ready for analysis and reporting.
- Config: Metadata schema used for ELT process.

Deployment instructions for the solution, along with requirements, are provided in the [deployment.md](https://github.com/AstralForest/Power_BI_Monitoring/blob/master/deployment.md) file. For the demo purposes, we create all necessary resources from scratch, but the solution is highly customizable and can be adapted to already existing resources.

**Important Note! There is also alterantive version of the soultion which uses Azure Functions for API processing (check out Azure-Functions branch). As a default we recommend using this version as it is less complicated, more secure and requires less resources. **

## Solution Design
The solution architecture consists of three main areas:

- **Orchestration** - the part overseeing the entire ETL process, ensuring timely processing of all tasks (Azure Data Factory)
- **Integration** - the area responsible for data extraction (Azure Data Factory - Copy Activity)
- **Transformation** - the section that further processes the acquired data, making it more accessible for final reporting (Azure SQL Database)
  
Each of these areas is independent and modular, allowing for the implementation of more fitting components tailored to specific client requirements.

## Considerations
- As per Microsoft documentation - some metrics will expose names, email addresses of users who have access to Power BI Service.

## Contact
If you have any questions or you are interested in the premium version that encompasses all functionalities, such as:
- 25 more SQL objects
- Access to latest features
- Professional setup and configuration tailored to your individual needs
- Recommendations about your current Power BI design
- Network security
- And much more...

Contact us at https://astralforest.com/  or michal.debski@astralforest.com

Additionally, we offer 2-3 hours of complimentary consultation in case of issues for deployment of the open-source version.

