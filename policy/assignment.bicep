// Assigns the custom policy definitions in Deny mode at subscription scope.
// enforcementMode 'Default' enforces the deny effect (blocks deployments).
// The definitions must exist first — see README "Deploy".
targetScope = 'subscription'

resource denyPublicIngress 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'deny-public-ingress'
  properties: {
    displayName: 'Deny public Container Apps ingress'
    enforcementMode: 'Default'
    policyDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/policyDefinitions/deny-public-ingress'
  }
}

resource denyInsecureTransport 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'deny-insecure-transport'
  properties: {
    displayName: 'Deny insecure transport (allowInsecure) on Container Apps'
    enforcementMode: 'Default'
    policyDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/policyDefinitions/deny-insecure-transport'
  }
}

resource denyPlaintextSecrets 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'deny-plaintext-secrets'
  properties: {
    displayName: 'Deny plaintext secrets in Container Apps env vars'
    enforcementMode: 'Default'
    policyDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/policyDefinitions/deny-plaintext-secrets'
  }
}

resource requireManagedIdentity 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'require-managed-identity'
  properties: {
    displayName: 'Require user-assigned managed identity on Container Apps'
    enforcementMode: 'Default'
    policyDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/policyDefinitions/require-managed-identity'
  }
}

resource denyLatestTag 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'deny-latest-tag'
  properties: {
    displayName: 'Deny :latest image tag on Container Apps'
    enforcementMode: 'Default'
    policyDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/policyDefinitions/deny-latest-tag'
  }
}

resource denyOverprivilegedRole 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'deny-overprivileged-role'
  properties: {
    displayName: 'Deny Contributor/Owner role assignments at resource group scope'
    enforcementMode: 'Default'
    policyDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/policyDefinitions/deny-overprivileged-role'
  }
}
