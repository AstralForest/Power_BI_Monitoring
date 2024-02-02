## Project Origin
While working with clients, we encountered growing need for monitoring and managing Power BI Service. To address this need, we have developed a comprehensive solution that covers the following aspects:
- Listing most active users and reports
- Monitoring the assignment and usage of Power BI licenses
- Tracking new reports deployment
- Maintaining order in Power BI Service by identifying unused reports
- Monitoring number of users and their activities
  
The end result is a Power BI report enabling you to monitor mentioned metrics:

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/484bcea1-6651-4e78-b755-14ba44fcfcbf)

**Please note that this is open-source version which does not include all mentioned above functionalities. In order to get the full solution premium, please contact: info@astralforest.com.**

## Project Description
Project leverages Power BI and Graph API queries to fetch data from Power BI Service. APIs are interfaces that allow programmatically access and interact with data from different platforms (in this case - Azure, Power BI Portal). Subsequently, the data is loaded to Azure SQL Database through Azure Data Factory — a cloud-based service designed for orchestrating and automating the data movement from different sources to various destinations. In the Azure SQL Database, the data undergoes processing and transformation into Facts and Dimensions where it serves as the foundation for generating a comprehensive Power BI Monitoring report.

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/e7039acd-23c1-4a72-84d3-3d3e44a57f86)

Function App makes API calls and processes the data, saves the output to Blob Storage from where it is copied to SQL Database

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/89f0d420-d0f9-49f8-993e-6a7203e95f2a)

Database consists of 4 schemas:
- Bronze: Initial stage containing unprocessed raw data.
- Silver: Intermediate layer for data processing and transformation.
- Gold: Final stage with fully cleansed and report-oriented data ready for analysis and reporting.
- Config: Metadata schema used for ELT process.

Deployment instructions for the solution, along with requirements, are provided in the [deployment.md](https://github.com/AstralForest/Power_BI_Monitoring/blob/master/deployment.md) file. For the demo purposes, we create all necessary resources from scratch, but the solution is highly customizable and can be adapted to already existing resources.

## Solution Design
The solution architecture consists of three main areas:

- **Orchestration** - the part overseeing the entire ETL process, ensuring timely processing of all tasks (Azure Data Factory)
- **Integration** - the area responsible for data extraction (Function App)
- **Transformation** - the section that further processes the acquired data, making it more accessible for final reporting (Azure SQL Database)
  
Each of these areas is independent and modular, allowing for the implementation of more fitting components tailored to specific client requirements.

![image](https://github.com/AstralForest/Power_BI_Monitoring/assets/156897451/884fd5f5-ec37-4431-a1ff-0ff160a199fc)

## Considerations
- The open-source solution does not include modules ensuring network security (Function App can be accessed by anyone possesing function key). For network security configuration, consider the premium version.
- As per Microsoft documentation - some metrics will expose names, email addresses of useras who are accessing Power BI Service.

## Contact
If you have any questions or you are interested in the premium version that encompasses all functionalities, such as:
- Professional setup and configuration tailored to your individual needs
- High level of network security
- List of most active users and reports
- Monitoring of assignment and usage of Power BI licenses
- And much more...

Contact us at https://astralforest.com/  or michal.debski@astralforest.com

