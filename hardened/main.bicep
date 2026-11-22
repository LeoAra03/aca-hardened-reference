// HARDENED — the "after". Same app, deployed the way you would hand it to a
// security reviewer: internal ingress with IP restrictions, Key Vault
// references instead of plaintext secrets, a user-assigned managed identity
// with least-privilege roles (AcrPull + Key Vault Secrets User), a pinned
// image, and minReplicas 1 so it is always up.
targetScope = 'resourceGroup'

param location string = 'westeurope'
param namePrefix string = 'aca-hardened'
// Replace with the CIDR that is allowed to reach the app.
param allowedCidr string = '10.0.0.0/8'
param imageName string = 'hello'
// Pinned tag — never the mutable latest tag (see policy/deny-latest-tag.json).
// Push your image to the ACR created below before first deploy.
param imageTag string = '1.0.0'
// Stored in Key Vault, referenced by the app — never in env vars.
param sampleSecret secureString
param budgetEmail string = ''
param retentionDays int = 30

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${namePrefix}-id'
  location: location
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01' = {
  name: take(toLower(replace('${namePrefix}${uniqueString(resourceGroup().id)}', '-', '')), 50)
  location: location
  sku: {
    name: 'Basic'
  }
  adminUserEnabled: false
  publicNetworkAccess: 'Enabled'
}

// Least privilege: the identity can only pull images from this ACR.
resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, identity.properties.principalId, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: take(toLower(replace('${namePrefix}${uniqueString(resourceGroup().id)}', '-', '')), 24)
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true
  }
}

resource kvSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'DbPassword'
  properties: {
    value: sampleSecret
  }
}

// Least privilege: the identity can only read secrets from this vault.
resource kvSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, identity.properties.principalId, 'KVSecretsUser')
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${namePrefix}-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
  }
}

resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${namePrefix}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: law.properties.customerId
        sharedKey: law.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${namePrefix}-app'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false // internal only — no public FQDN
        targetPort: 8080
        transport: 'http'
        ipSecurityRestrictions: [
          {
            name: 'allow-app-vnet'
            description: 'Allow only the app network'
            action: 'Allow'
            ipAddressRange: allowedCidr
          }
        ]
        ipSecurityRestrictionsDefaultAction: 'Deny'
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: identity.id
        }
      ]
      secrets: [
        {
          name: 'db-password'
          keyVaultUrl: '${kv.properties.vaultUri}secrets/DbPassword'
          identity: identity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'hello'
          image: '${acr.properties.loginServer}/${imageName}:${imageTag}'
          resources: {
            cpu: 0.25
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'DB_PASSWORD'
              secretRef: 'db-password' // resolved from Key Vault at runtime
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/'
                port: 8080
              }
              initialDelaySeconds: 5
              periodSeconds: 30
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1 // always up — availability baseline
        maxReplicas: 2
      }
    }
  }
}

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = if (budgetEmail != '') {
  name: '${namePrefix}-budget'
  scope: resourceGroup()
  properties: {
    category: 'Cost'
    amount: 20
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: utcNow('yyyy-MM-dd')
      endDate: '2035-01-01T00:00:00Z'
    }
    notifications: {
      ActualGT80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        contactEmails: [
          budgetEmail
        ]
      }
    }
  }
}

output appFqdn string = app.properties.configuration.ingress.fqdn
output acrLoginServer string = acr.properties.loginServer
output keyVaultName string = kv.name
