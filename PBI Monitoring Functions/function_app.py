import azure.functions as func
# This ensures that function app deploys to the Azure and its easier to troubleshoot it there
try:
    import json
    import requests
    import pandas as pd
    from azure.storage.blob import BlobServiceClient
    import io
    from datetime import datetime, timedelta
    import logging
    from azure.identity import DefaultAzureCredential
    from azure.keyvault.secrets import SecretClient
except:
    pass

"""
- The code follows the PEP8 standard (link: https://peps.python.org/pep-0008/ .
- There are functions for tasks that are repeated more than a few times, such as token acquisition, REST API request, saving files to blob storage, table formatting.
- When adding a new library, make sure to include it in the requirements.txt file along with its version.
"""
try:
    credential = DefaultAzureCredential()

    # Change vault_url in order to fit your KV name
    secret_client = SecretClient(vault_url='https://kv-af-pbimon-0.vault.azure.net', credential=credential)

    api_client_secret = secret_client.get_secret('secret-pbimon-app-reg-secret').value
    api_client_id = secret_client.get_secret('secret-pbimon-app-reg-client').value
    azure_tenant_id = secret_client.get_secret('secret-pbimon-tenant-id').value
    storage_key = secret_client.get_secret('secret-pbimon-storage').value
    token_endpoint = f'https://login.microsoftonline.com/{azure_tenant_id}/oauth2/token'
    account_name = secret_client.get_secret('secret-pbimon-storage-name').value
    GRAPH_API_URL = "https://graph.microsoft.com/v1.0/"
    POWERBI_API_ADMIN_URL = "https://api.powerbi.com/v1.0/myorg/admin/"
    pbi_access_token = ''
    graph_access_token = ''
except:
    pass

def pbi_get_bearer_token() -> str:
    """
    Generate access token for Power BI.
    """
    body = {
        "grant_type": "client_credentials",
        "client_id": api_client_id,
        "client_secret": api_client_secret,
        "resource": "https://analysis.windows.net/powerbi/api"
    }
    access_token_response = requests.post(token_endpoint, data=body)
    pbi_access_token = access_token_response.json().get("access_token")

    return pbi_access_token

def graph_get_bearer_token() -> str:
    """
    Generate access token for Graph API.
    """
    body = {
        "grant_type": "client_credentials",
        "client_id": api_client_id,
        "client_secret": api_client_secret,
        "resource": "https://graph.microsoft.com"
    }
    access_token_response = requests.post(token_endpoint, data=body)
    graph_access_token = access_token_response.json().get("access_token")

    return graph_access_token


def make_request(api_url : str) -> json:
    """
    Make API requests and returns json response. Generate new access token if needed.
    """
    global pbi_access_token
    global graph_access_token
    if 'myorg/admin' in api_url:
        headers = {
        "Authorization": f"Bearer {pbi_access_token}"
        }

        try:
            response = requests.get(api_url, headers=headers)
            response.raise_for_status()
        except requests.exceptions.HTTPError as http_err:
            # Get new access token if current one is expired
            if response.status_code == 401 or response.status_code == 403:
                pbi_access_token = pbi_get_bearer_token()
                headers = {
                    "Authorization": f"Bearer {pbi_access_token}"
                }
                response = requests.get(api_url, headers=headers)
                response.raise_for_status()
                return response.json()
            else:
                # Other http error
                logging.error(f"Failed GET request: {http_err}")
                return None
        except requests.exceptions.RequestException as err:
            logging.error(f"Failed GET request: {err}")
            return None

    elif 'graph' in api_url:
        headers = {
        "Authorization": f"Bearer {graph_access_token}"
        }
        try:
            response = requests.get(api_url, headers=headers)
            response.raise_for_status()
        except requests.exceptions.HTTPError as http_err:
            # Get new access token if current one is expired
            if response.status_code == 401 or response.status_code == 403:
                graph_access_token = graph_get_bearer_token()
                headers = {
                    "Authorization": f"Bearer {graph_access_token}"
                }
                response = requests.get(api_url, headers=headers)
                response.raise_for_status()
                return response.json()
            else:
                # Other http error
                logging.error(f"Failed GET request: {http_err}")
                return None
        except requests.exceptions.RequestException as err:
            logging.error(f"Failed GET request: {err}")
            return None
    
    return response.json()


def write_to_blob(df : pd.DataFrame, load_name : str) -> None:
    """
    Save the DataFrame as csv to blob storage.
    """
    today = datetime.now().strftime('%Y-%m-%d')
    container_name = "staging"
    blob_path = f"{load_name}/{today}/{load_name}.csv"
    # Connect to blob
    blob_service_client = BlobServiceClient(account_url=f"https://{account_name}.blob.core.windows.net", credential=storage_key)
    container_client = blob_service_client.get_container_client(container_name)
    blob_client = container_client.get_blob_client(blob_path)
    # Save dataframe to csv
    csv_data = df.to_csv(index=False)
    csv_bytes = csv_data.encode("utf-8")
    # Upload file to blob
    with io.BytesIO(csv_bytes) as upload:
        blob_client.upload_blob(upload, overwrite=True)


def process_api_response(response: json, additional_columns=None) -> pd.DataFrame:
    """
    Dynamically load the data from API response into a list, convert it to DataFrame and add requestDate.
    """
    columns = set()
    for item in response['value']:
        columns.update(item.keys())
    # Add additional columns to the set. (for example you list reports for workspace -> then you should pass workspaceId to the additional_columns)
    if additional_columns:
        columns.update(additional_columns.keys())
    data = []
    for item in response['value']:
        row_data = {col: item.get(col) for col in columns}
        if additional_columns:
            row_data.update(additional_columns)
        data.append(row_data)

    today = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    df = pd.DataFrame(data)
    df['requestDate'] = today

    return df


app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)
@app.route(route="get_reports", auth_level=func.AuthLevel.FUNCTION)
def get_reports(req: func.HttpRequest) -> func.HttpResponse:
    try:
        logging.info("Function started.")
        api_url = f"{POWERBI_API_ADMIN_URL}reports"
        response = make_request(api_url)
        df = process_api_response(response)
        logging.info("Data generated successfully. Starting connection to blob storage.")          
        load_name = 'reports'
        write_to_blob(df, load_name)
        logging.info("Function executed without errors.")
        return func.HttpResponse(f"{df}")
    except Exception as e:
        return func.HttpResponse(f"An error occurred: {str(e)}", status_code=500)


@app.route(route="get_workspaces", auth_level=func.AuthLevel.FUNCTION)
def get_workspaces(req: func.HttpRequest) -> func.HttpResponse:
    try:
        logging.info("Function started.")
        api_url = f"{POWERBI_API_ADMIN_URL}groups?$top=5000"
        response = make_request(api_url)
        df = process_api_response(response)
        logging.info("Data generated successfully. Starting connection to blob storage.")          
        load_name = 'workspaces'
        write_to_blob(df, load_name)
        logging.info("Function executed without errors.")
        return func.HttpResponse(f"{df}")
    except Exception as e:
        return func.HttpResponse(f"An error occurred: {str(e)}", status_code=500)


@app.route(route="get_graph_groups", auth_level=func.AuthLevel.FUNCTION)
def get_graph_groups(req: func.HttpRequest) -> func.HttpResponse:
    try:
        logging.info("Function started.")
        api_url = f"{GRAPH_API_URL}groups/?$select=id,displayName"
        response = make_request(api_url)
        df = process_api_response(response)
        logging.info("Data generated successfully. Starting connection to blob storage.")          
        load_name = 'graphgroups'
        write_to_blob(df, load_name)
        logging.info("Function executed without errors.")
        return func.HttpResponse(f"{df}")
    except Exception as e:
        return func.HttpResponse(f"An error occurred: {str(e)}", status_code=500)


@app.route(route="get_graph_users", auth_level=func.AuthLevel.FUNCTION)
def get_graph_users(req: func.HttpRequest) -> func.HttpResponse:
    try:
        logging.info("Function started.")
        api_url = f"{GRAPH_API_URL}users?$select=id,displayName,givenName,surname,mail,mailNickname,jobTitle,department,companyName,officeLocation,city,accountEnabled"
        response = make_request(api_url)
        df = process_api_response(response)
        logging.info("Data generated successfully. Starting connection to blob storage.")          
        load_name = 'graphusers'
        write_to_blob(df, load_name)
        logging.info("Function executed without errors.")
        return func.HttpResponse(f"{df}")
    except Exception as e:
        return func.HttpResponse(f"An error occurred: {str(e)}", status_code=500)


@app.route(route="get_activity_events", auth_level=func.AuthLevel.FUNCTION)
def get_activity_events(req: func.HttpRequest) -> func.HttpResponse:
    """
    For big organization this request can potentially time out (too many requests). 
    The list of available columns and activities may change (currently there around 200 of them).
    """
    try:
        datetime.now().strftime('%Y-%m-%d')
        yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
        data = []
        api_url = f"{POWERBI_API_ADMIN_URL}activityevents?startDateTime='{yesterday}T00:00:00Z'&endDateTime='{yesterday}T23:59:59Z'"
        while api_url is not None:
            activities_json = make_request(api_url)
            for item in activities_json['activityEventEntities']:
                   data.append({
                    'Id': item.get('Id'),
                    'RecordType': item.get('RecordType'),
                    'CreationTime': item.get('CreationTime'),
                    'Operation': item.get('Operation'),
                    'OrganizationId': item.get('OrganizationId'),
                    'UserType': item.get('UserType'),
                    'UserKey': item.get('UserKey'),
                    'Workload': item.get('Workload'),
                    'UserId': item.get('UserId'),
                    'ClientIP': item.get('ClientIP'),
                    'UserAgent': item.get('UserAgent'),
                    'Activity': item.get('Activity'),
                    'ItemName': item.get('ItemName'),
                    'WorkSpaceName': item.get('WorkSpaceName'),
                    'ReportName': item.get('ReportName'),
                    'DashboardName': item.get('DashboardName'),
                    'AppName': item.get('AppName'),
                    'OrgAppPermission': item.get('OrgAppPermission'),
                    'WorkspaceId': item.get('WorkspaceId'),
                    'ObjectId': item.get('ObjectId'),
                    'ReportId': item.get('ReportId'),
                    'DashboardId': item.get('DashboardId'),
                    'AppReportId': item.get('AppReportId'),
                    'AppDashboardId': item.get('AppDashboardId'),
                    'IsSuccess': item.get('IsSuccess'),
                    'ReportType': item.get('ReportType'),
                    'RequestId': item.get('RequestId'),
                    'ActivityId': item.get('ActivityId'),
                    'DistributionMethod': item.get('DistributionMethod'),
                    'ConsumptionMethod': item.get('ConsumptionMethod'),
                    'DataConnectivityMode': item.get('DataConnectivityMode'),
                    'CapacityId': item.get('CapacityId'),
                    'CapacityName': item.get('CapacityName'),
                    'CapacityUsers': item.get('CapacityUsers'),
                    'CapacityState': item.get('CapacityState'),
                    'TileId': item.get('TileId'),
                    'TileName': item.get('TileName'),
                    'TileText': item.get('TileText'),
                    'ExportEventStartDateTimeParameter': item.get('ExportEventStartDateTimeParameter'),
                    'ExportEventEndDateTimeParameter': item.get('ExportEventEndDateTimeParameter'),
                    'FolderObjectId': item.get('FolderObjectId'),
                    'FolderDisplayName': item.get('FolderDisplayName'),
                    'CustomVisualAccessTokenSiteUri': item.get('CustomVisualAccessTokenSiteUri'),
                    'EmbedTokenId': item.get('EmbedTokenId'),
                    'StorageAccountName': item.get('StorageAccountName'),
                    'CustomVisualAccessTokenResourceId': item.get('CustomVisualAccessTokenResourceId'),
                    'ArtifactId': item.get('ArtifactId'),
                    'ArtifactName': item.get('ArtifactName'),
                    'TableName': item.get('TableName'),
                    'DataflowId': item.get('DataflowId'),
                    'DataflowName': item.get('DataflowName'),
                    'DataflowType': item.get('DataflowType'),
                    'DataflowAllowNativeQueries': item.get('DataflowAllowNativeQueries'),
                    'DatasetId': item.get('DatasetId'),
                    'DatasetName': item.get('DatasetName'),
                    'DatasourceId': item.get('DatasourceId'),
                    'DatasourceName': item.get('DatasourceName'),
                    'ImportId': item.get('ImportId'),
                    'ImportSource': item.get('ImportSource'),
                    'ImportType': item.get('ImportType'),
                    'ImportDisplayName': item.get('ImportDisplayName'),
                    'RefreshType': item.get('RefreshType'),
                    'GatewayId': item.get('GatewayId'),
                    'GatewayName': item.get('GatewayName'),
                    'GatewayType': item.get('GatewayType'),
                    'MentionedUsersInformation': item.get('MentionedUsersInformation'),
                    'AuditedArtifactInformationArtifactId': item.get('AuditedArtifactInformationArtifactId'),
                    'AuditedArtifactInformationName': item.get('AuditedArtifactInformationName'),
                    'AuditedArtifactInformationArtifactObjectId': item.get('AuditedArtifactInformationArtifactObjectId'),
                    'AuditedArtifactInformationAnnotatedItemType': item.get('AuditedArtifactInformationAnnotatedItemType'),
                    'DatasetDatasetId': item.get('DatasetDatasetId'),
                    'DatasetDatasetName': item.get('DatasetDatasetName'),
                    'DatasourceDatasourceType': item.get('DatasourceDatasourceType'),
                    'DatasourceConnectionDetails': item.get('DatasourceConnectionDetails'),
                    'ExportedArtifactInfoExportType': item.get('ExportedArtifactInfoExportType'),
                    'ExportedArtifactInfoArtifactType': item.get('ExportedArtifactInfoArtifactType'),
                    'ExportedArtifactInfoArtifactId': item.get('ExportedArtifactInfoArtifactId'),
                    'FolderAccessRolePermissions': item.get('FolderAccessRolePermissions'),
                    'FolderAccessUserObjectId': item.get('FolderAccessUserObjectId'),
                    'MembershipInformationMemberEmail': item.get('MembershipInformationMemberEmail'),
                    'SchedulesRefreshFrequency': item.get('SchedulesRefreshFrequency'),
                    'SchedulesTimeZone': item.get('SchedulesTimeZone'),
                    'SchedulesDays': item.get('SchedulesDays'),
                    'SchedulesTime': item.get('SchedulesTime'),
                    'SharingInformationRecipientEmail': item.get('SharingInformationRecipientEmail'),
                    'SharingInformationResharePermission': item.get('SharingInformationResharePermission'),
                    'SubscribeeInformationRecipientEmail': item.get('SubscribeeInformationRecipientEmail'),
                    'SubscribeeInformationRecipientName': item.get('SubscribeeInformationRecipientName'),
                    'SubscribeeInformationObjectId': item.get('SubscribeeInformationObjectId'),
                    'UserInformationUsersAdded': item.get('UserInformationUsersAdded'),
                    'UserInformationUsersRemoved': item.get('UserInformationUsersRemoved'),
                    'WorkspaceAccessListWorkspaceId': item.get('WorkspaceAccessListWorkspaceId'),
                    'CopiedReportId': item.get('CopiedReportId'),
                    'CopiedReportName': item.get('CopiedReportName')
                })
            api_url = activities_json.get('continuationUri')

        today = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        df = pd.DataFrame(data)
        df['requestDate'] = today
        logging.info("Data generated successfully. Starting connection to blob storage.")
        load_name = 'activityevents'
        write_to_blob(df, load_name)
        logging.info("Function executed without errors.")
        return func.HttpResponse(f"{df}")
    except Exception as e:
        return func.HttpResponse(f"An error occurred: {str(e)}", status_code=500)

