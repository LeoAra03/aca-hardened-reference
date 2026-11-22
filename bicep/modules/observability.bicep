// Log Analytics workspace with bounded 30-day retention. Real telemetry,
// bounded spend — the retention is the cost control.
targetScope = 'resourceGroup'

param location string
param name string = 'law-aca-ref'
param retentionDays int = 30

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output workspaceId string = law.id
output customerId string = law.properties.customerId
output primarySharedKey string = law.listKeys().primarySharedKey
