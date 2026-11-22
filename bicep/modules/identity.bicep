// User-assigned managed identity. The app pulls from ACR and writes to
// Log Analytics with this identity — no connection strings, no passwords.
targetScope = 'resourceGroup'

param location string
param name string = 'id-aca-ref'

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
}

output identityId string = identity.id
output principalId string = identity.properties.principalId
output clientId string = identity.properties.clientId
