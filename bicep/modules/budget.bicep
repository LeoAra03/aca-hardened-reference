// Consumption budget with email alarms. Container Apps has no hard spend
// cap, so the alarm + scale-to-zero is the blast-radius control.
targetScope = 'resourceGroup'

param amount int = 20
param email string
param startDate string = utcNow('yyyy-MM-dd')
param endDate string = '2035-01-01T00:00:00Z'

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: 'budget-aca-ref'
  scope: resourceGroup()
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
      endDate: endDate
    }
    notifications: {
      ActualGT80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        contactEmails: [
          email
        ]
      }
      ActualGT100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        contactEmails: [
          email
        ]
      }
    }
  }
}
