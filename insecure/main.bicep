// INSECURE — the "before". Same app, deployed the way a quick sample does it:
// public ingress, plain HTTP, plaintext secrets in env vars, a system-assigned
// identity with Contributor on the whole resource group, and a :latest image.
// Every line here is what the policies in ../policy deny. Do not deploy this
// to a real subscription.
targetScope = 'resourceGroup'

param location string = 'westeurope'
param namePrefix string = 'aca-insecure'

resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${namePrefix}-env'
  location: location
  properties: {
    zoneRedundant: false
  }
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${namePrefix}-app'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true // public FQDN, reachable from the internet
        allowInsecure: true // plain HTTP, no TLS
        targetPort: 80
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'web'
          image: 'nginx:latest' // mutable tag, unreproducible deploys
          resources: {
            cpu: 0.25
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'DB_PASSWORD'
              value: 'SuperSecret123!' // plaintext secret in the template
            }
            {
              name: 'API_KEY'
              value: 'sk-live-000000000000000000000000' // plaintext secret
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 2
      }
    }
  }
}

// The app identity gets Contributor on the entire resource group:
// it can read/write/delete everything in the RG, not just pull images.
resource contributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, app.identity.principalId, 'Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b2497c52-6040-4519-a36c-8a0f3c35f8d2')
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output appFqdn string = app.properties.configuration.ingress.fqdn
