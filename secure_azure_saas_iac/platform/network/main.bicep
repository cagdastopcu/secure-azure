// Network baseline for the SaaS stamp.
// Why: explicit private boundaries for runtime and private endpoints.
targetScope = 'resourceGroup'

param location string
param projectPrefix string
param environment string
param vnetAddressPrefix string
param acaInfraSubnetPrefix string
param privateEndpointSubnetPrefix string
param tags object = {}

var vnetName = '${projectPrefix}-${environment}-vnet'
var acaInfraSubnetName = 'snet-aca-infra'
var privateEndpointSubnetName = 'snet-private-endpoints'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        // Required by ACA managed environment deployment.
        name: acaInfraSubnetName
        properties: {
          addressPrefix: acaInfraSubnetPrefix
          delegations: [
            {
              name: 'aca-delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        // Required for Private Endpoint subnet behavior.
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output vnetName string = vnet.name
output acaInfraSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, acaInfraSubnetName)
output privateEndpointSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
