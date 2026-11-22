// INSECURE — deployable, plausible, wrong. This is the default output of
// most scaffolding tools: public ingress, plain HTTP, literal secrets,
// no identity, :latest image, no diagnostics, no probes.
targetScope = 'resourceGroup'

param location string = 'eastus'
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
  // No identity block: the app runs with no managed identity at all.
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true // public FQDN, reachable from anywhere
        allowInsecure: true // plain HTTP, bearer tokens in cleartext
        targetPort: 80
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'web'
          image: 'nginx:latest' // mutable tag, no rollback target
          resources: {
            cpu: 0.25
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'DB_PASSWORD'
              value: 'SuperSecret123!' // literal secret, visible in ARM history
            }
            {
              name: 'API_KEY'
              value: 'sk-live-000000000000000000000000' // literal secret
            }
          ]
          // No probes: traffic goes to half-started replicas.
        }
      ]
      scale: {
        minReplicas: 0 // cold starts mask DoS as "slow app"
        maxReplicas: 2
      }
    }
  }
}

output appFqdn string = app.properties.configuration.ingress.fqdn
