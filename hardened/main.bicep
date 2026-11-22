// HARDENED — the corrected version, one control at a time. Internal
// ingress with IP restrictions, HTTPS-only transport, Key Vault references,
// user-assigned identity with least-privilege roles, digest-pinned image,
// minReplicas 1, user-defined egress via firewall UDR, Log Analytics
// diagnostics, and liveness + readiness probes.
targetScope = 'resourceGroup'

param location string = 'eastus'
param namePrefix string = 'aca-hardened'
// Replace with the CIDR that is allowed to reach the app.
param allowedCidr string = '10.0.0.0/8'
param imageName string = 'hello'
param imageTag string = '1.0.0'
// Digest pin, never a mutable tag. Get the real digest with:
//   az acr repository show --name <acr> --image hello:1.0.0 --query digest
param imageDigest string = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
// Placeholder firewall IP. The egress UDR assumes a firewall that is not
// in this repo — replace with your Azure Firewall / appliance address.
param firewallIp string = '10.0.0.4'
// Stored in Key Vault, referenced by the app — never in env vars.
param sampleSecret secureString
param budgetEmail string = ''
param retentionDays int = 30

// --- Egress: user-defined outbound via UDR to firewall ---
resource udr 'Microsoft.Network/routeTables@2023-11-01' = {
  name: '${namePrefix}-udr'
  location: location
  properties: {
    routes: [
      {
        name: 'to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopInIpAddress: firewallIp
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${namePrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: vnet
  name: 'aca-subnet'
  properties: {
    addressPrefix: '10.0.0.0/23'
    routeTable: {
      id: udr.id
    }
  }
}

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
    vnetConfiguration: {
      internalOnly: true
      outboundType: 'userDefined' // egress via UDR to firewall, inspected
      subnetId: subnet.id
    }
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
        allowInsecure: false // HTTPS only
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
          image: '${acr.properties.loginServer}/${imageName}@${imageDigest}' // digest pin
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
                path: '/healthz'
                port: 8080
              }
              initialDelaySeconds: 5
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/readyz'
                port: 8080
              }
              initialDelaySeconds: 5
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1 // always up — no cold-start auth timeouts
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
