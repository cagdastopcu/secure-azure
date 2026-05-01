// Network baseline module.
// Creates one VNet with:
// - delegated subnet for Azure Container Apps environment infrastructure
// - subnet for private endpoints
targetScope = 'resourceGroup'

// Deployment region for all network resources in this module.
param location string
// Naming and ownership context.
param projectPrefix string
param environment string
// Network ranges provided by root template.
param vnetAddressPrefix string
param acaInfraSubnetPrefix string
param privateEndpointSubnetPrefix string
// Governance tags propagated from root.
param tags object = {}

var vnetName = '${projectPrefix}-${environment}-vnet'
var acaInfraSubnetName = 'snet-aca-infra'
var privateEndpointSubnetName = 'snet-private-endpoints'

// Single VNet is used as the private boundary for the stamp.
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
        // ACA environment requires subnet delegation to Microsoft.App/environments.
        // Without delegation, ACA environment deployment fails.
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
        // Private endpoint policies disabled as required for PE subnet.
        // This is necessary for Private Endpoint NIC attachment behavior.
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Output IDs are consumed by other modules instead of hardcoding names.
output vnetName string = vnet.name
output acaInfraSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, acaInfraSubnetName)
output privateEndpointSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
