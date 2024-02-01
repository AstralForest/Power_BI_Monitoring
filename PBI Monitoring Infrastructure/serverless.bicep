// Object names
param instance string
param client_name string

param data_factory_name string = 'adf-${client_name}-pbimon-${instance}'
param function_name string = 'func-${client_name}-pbimon-${instance}'
param app_service_plan_name string = 'asp-${client_name}-pbimon-${instance}'
param vault_name string = 'kv-${client_name}-pbimon-${instance}'
param server_name string = 'server-${client_name}-pbimon-${instance}'
param db_name string = 'db-${client_name}-pbimon-${instance}'
param storage_name string = 'st${client_name}pbimon${instance}'
param func_storage_name string = 'stfunc${client_name}pbimon${instance}'

// Tenant
param tenant_id string

// Region
param region_uppercase string
param region string

param rg_owner_id string
param server_admin_mail string
param admin_sid string

// Key Vault secrets
@secure()
param server_password string = newGuid()
@secure()
param app_reg_client string
@secure()
param app_reg_secret string

// (1) Data Factory
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: data_factory_name
  location: region
  identity: {
    type: 'SystemAssigned'
  }
}

// (2) App Service Plan + Function Storage + Function App
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: app_service_plan_name
  location: region
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// (2b) Function Storage + Role Assignment
resource functionStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  location: region
  name: func_storage_name
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
  }
}

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: functionStorage
  name: guid(functionStorage.id, rg_owner_id, contributorRoleDefinition.id)
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: rg_owner_id
    principalType: 'User'
  }
}

resource functionStorageDefault 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: functionStorage
  name: 'default'
}

resource functionStorageServices 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: functionStorage
  name: 'default'
}

resource functionStorageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: functionStorageDefault
  name: 'azure-webjobs-hosts'
}

resource functionStorageContainer2 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: functionStorageDefault
  name: 'azure-webjobs-secrets'
}

resource functionStorageContainer3 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: functionStorageDefault
  name: 'bacpac'
}


// (2c) Function App
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: function_name
  location: region_uppercase
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${func_storage_name};AccountKey=${listKeys(functionStorage.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'AzureWebJobsFeatureFlags'
          value: 'EnableWorkerIndexing'
        }
      ]
      netFrameworkVersion: 'v4.0'
      linuxFxVersion: 'Python|3.11'
      alwaysOn: false
    }
  }
}


// (3) SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-02-01-preview' = {
  name: server_name
  location: region
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: 'login_server_pbimon'
    administratorLoginPassword: server_password
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: server_admin_mail
      sid: admin_sid
      tenantId: tenant_id
      azureADOnlyAuthentication: false
    }
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

resource symbolicname 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  name: 'firewall'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// (4) Storage
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storage_name
  location: region
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource storageDefault 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: storageDefault
  name: 'staging'
}

// (5) Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vault_name
  location: region
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant_id
    accessPolicies: [
      {
        tenantId: tenant_id
        objectId: rg_owner_id
        permissions: {
          keys: [
            'Get'
            'List'
            'Update'
            'Create'
            'Import'
            'Delete'
            'Recover'
            'Backup'
            'Restore'
            'GetRotationPolicy'
            'SetRotationPolicy'
            'Rotate'
            'Encrypt'
            'Decrypt'
            'UnwrapKey'
            'WrapKey'
            'Verify'
            'Sign'
            'Purge'
            'Release'
          ]
          secrets: [
            'Get'
            'List'
            'Set'
            'Delete'
            'Recover'
            'Backup'
            'Restore'
            'Purge'
          ]
          certificates: [
            'Get'
            'List'
            'Update'
            'Create'
            'Import'
            'Delete'
            'Recover'
            'Backup'
            'Restore'
            'ManageContacts'
            'ManageIssuers'
            'GetIssuers'
            'ListIssuers'
            'SetIssuers'
            'DeleteIssuers'
            'Purge'
          ]
        }
      }
      {
        tenantId: tenant_id
        objectId: functionApp.identity.principalId
        permissions: {
          certificates: [
            'Get'
            'List'
          ]
          keys: [
            'Get'
            'List'
          ]
          secrets: [
            'Get'
            'List'
          ]
        }
      }
      {
        tenantId: tenant_id
        objectId: dataFactory.identity.principalId
        permissions: {
          certificates: [
            'get'
            'list'
          ]
          keys: [
            'get'
            'list'
          ]
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// (5a) Secrets
resource secretServer 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'secret-pbimon-server'
  properties: {
    value: server_password
  }
}

resource secretStorageKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'secret-pbimon-storage'
  properties: {
    value: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
  }
}

resource secretStorageName 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'secret-pbimon-storage-name'
  properties: {
    value: storage_name
  }
}

resource secretAppRegistrationClient 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'secret-pbimon-app-reg-client'
  properties: {
    value: app_reg_client
  }
}

resource secretAppRegistrationSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'secret-pbimon-app-reg-secret'
  properties: {
    value: app_reg_secret
  }
}

resource secretDatabaseConnectionString'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'secret-pbimon-db-connection-string'
  properties: {
    value: '${'Server=tcp:'}${server_name}.database.windows.net,1433;Database=${db_name};User ID=login_server_pbimon;Password=${server_password};Trusted_Connection=False;Encrypt=True;'
  }
}

resource secretStorageConnectionString'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'secret-pbimon-storage-connection-string'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storage_name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value};'
  }
}

resource secretTenantId 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'secret-pbimon-tenant-id'
  properties: {
    value: tenant_id
  }
}

// Access Function App key 
resource functionAppHost 'Microsoft.Web/sites/host@2022-09-01' existing = {
  name: 'default'
  parent: functionApp
}

resource secretFunctionAppSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'secret-pbimon-func-app-secret'
  properties: {
    value: functionAppHost.listKeys().functionKeys.default
  }
}






