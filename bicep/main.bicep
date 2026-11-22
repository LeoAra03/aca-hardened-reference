// Hardened Azure Container Apps reference — entry point.
// Private ingress, user-assigned managed identity, zero secrets,
// ACR pull via identity, Log Analytics, budget alarm.
targetScope = 'resourceGroup'

param location string = 'westeurope'
param namePrefix string = 'aca-ref'
// Exposure is an explicit opt-in. Default false = internal only.
param externalIngress bool = false
param budgetEmail string
param budgetAmount int = 20
param retentionDays int = 30
// Pinned image — never the mutable latest tag (see policy/deny-latest-tag.json).
// Push your image to the ACR created below before first deploy.
param imageName string = 'hello'
param imageTag string = '1.0.0'

module identity 'modules/identity.bicep' = {
  name: 'identity'
  params: {
    location: location
    name: '${namePrefix}-id'
  }
}

module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    location: location
    // ACR names are globally unique, alphanumeric, max 50 chars.
    name: take(toLower(replace('${namePrefix}${uniqueString(resourceGroup().id)}', '-', '')), 50)
    identityPrincipalId: identity.outputs.principalId
  }
}

module observability 'modules/observability.bicep' = {
  name: 'observability'
  params: {
    location: location
    retentionDays: retentionDays
  }
}

module aca 'modules/aca.bicep' = {
  name: 'aca'
  params: {
    location: location
    externalIngress: externalIngress
    containerImage: '${acr.outputs.loginServer}/${imageName}:${imageTag}'
    identityId: identity.outputs.identityId
    acrLoginServer: acr.outputs.loginServer
    logWorkspaceCustomerId: observability.outputs.customerId
    logWorkspaceSharedKey: observability.outputs.primarySharedKey
  }
}

module budget 'modules/budget.bicep' = {
  name: 'budget'
  params: {
    amount: budgetAmount
    email: budgetEmail
  }
}

output appFqdn string = aca.outputs.appFqdn
output appId string = aca.outputs.appId
output environmentId string = aca.outputs.environmentId
output acrLoginServer string = acr.outputs.loginServer
output identityId string = identity.outputs.identityId
output workspaceId string = observability.outputs.workspaceId
