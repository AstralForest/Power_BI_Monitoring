// Object names
param instance string
param client_name string

// Tenant
param tenant_id string

// Region
param region string

// Roles
param rg_owner_id string
param server_admin_mail string

// Key Vault secrets
@secure()
param server_password string = newGuid()
@secure()
param app_reg_client string
@secure()
param app_reg_secret string

var data_factory_name = 'adf-${client_name}-pbimon-${instance}'
var vault_name = 'kv-${client_name}-pbimon-${instance}'
var server_name = 'server-${client_name}-pbimon-${instance}'
var db_name = 'db-${client_name}-pbimon-${instance}'
var storage_name = 'st${client_name}pbimon${instance}'

// (1) Data Factory
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: data_factory_name
  location: region
  identity: {
    type: 'SystemAssigned'
  }
}

// (2) SQL Server
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
      sid: rg_owner_id
      tenantId: tenant_id
      azureADOnlyAuthentication: false
    }
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  name: db_name
  parent: sqlServer
  location: region
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
  sku: {
    name: 'S0'
    tier: 'Standard'
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

// (3) Storage + Contributor Role
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

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, rg_owner_id, contributorRoleDefinition.id)
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: rg_owner_id
    principalType: 'User'
  }
}

resource functionStorageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: storageDefault
  name: 'bacpac'
}

// (4) Key Vault
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

// (4a) Secrets
resource secretServer 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'secret-pbimon-server'
  properties: {
    value: server_password
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

resource secretTenantId 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'secret-pbimon-tenant-id'
  properties: {
    value: tenant_id
  }
}







