// Container Registry with the admin user disabled. The managed identity
// pulls images via the AcrPull role — no registry password anywhere.
targetScope = 'resourceGroup'

param location string
param name string
param sku string = 'Basic'
param identityPrincipalId string

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  adminUserEnabled: false
  publicNetworkAccess: 'Enabled'
  policies: {
    quarantinePolicy: {
      status: 'enabled'
    }
    trustPolicy: {
      type: 'Notary'
      status: 'disabled'
    }
    retentionPolicy: {
      days: 7
      status: 'disabled'
    }
  }
}

// AcrPull (7f951dda-4ed3-4680-a7ca-43fe172d538d) for the app identity.
resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, identityPrincipalId, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: identityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output acrId string = acr.id
output acrName string = acr.name
output loginServer string = acr.properties.loginServer
