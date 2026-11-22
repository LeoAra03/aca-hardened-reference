// Container Apps Environment + App. Internal ingress by default
// (externalIngress is an explicit opt-in), user-assigned identity,
// scale-to-zero, image pulled from ACR via that identity.
targetScope = 'resourceGroup'

param location string
param environmentName string = 'cae-aca-ref'
param appName string = 'ca-hello'
param externalIngress bool = false
param containerImage string
param identityId string
param acrLoginServer string
param logWorkspaceCustomerId string
param logWorkspaceSharedKey string
param minReplicas int = 0
param maxReplicas int = 2

resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logWorkspaceCustomerId
        sharedKey: logWorkspaceSharedKey
      }
    }
    zoneRedundant: false
  }
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: externalIngress
        targetPort: 8080
        transport: 'http'
      }
      registries: [
        {
          server: acrLoginServer
          identity: identityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'hello'
          image: containerImage
          resources: {
            cpu: 0.25
            memory: '0.5Gi'
          }
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
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output appId string = app.id
output appFqdn string = app.properties.configuration.ingress.fqdn
output environmentId string = env.id
