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
@description('If true, create and attach a DDoS Network Protection plan to this VNet.')
param enableDdosProtection bool = false
@description('If true, attach NSG to private endpoint subnet for explicit network boundary control.')
param enablePrivateEndpointSubnetNsg bool = true

var vnetName = '${projectPrefix}-${environment}-vnet'
var acaInfraSubnetName = 'snet-aca-infra'
var privateEndpointSubnetName = 'snet-private-endpoints'
var ddosPlanName = '${projectPrefix}-${environment}-ddos-plan'
var peNsgName = '${projectPrefix}-${environment}-pe-nsg'

resource ddosPlan 'Microsoft.Network/ddosProtectionPlans@2023-09-01' = if (enableDdosProtection) {
  name: ddosPlanName
  location: location
  tags: tags
}

resource privateEndpointSubnetNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = if (enablePrivateEndpointSubnetNsg) {
  name: peNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-vnet-inbound'
        properties: {
          priority: 100
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'allow-azure-loadbalancer-inbound'
        properties: {
          priority: 110
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'deny-internet-inbound'
        properties: {
          priority: 400
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    ddosProtectionPlan: enableDdosProtection ? {
      id: ddosPlan.id
    } : null
    enableDdosProtection: enableDdosProtection
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
          networkSecurityGroup: enablePrivateEndpointSubnetNsg ? {
            id: privateEndpointSubnetNsg.id
          } : null
        }
      }
    ]
  }
}

output vnetName string = vnet.name
output acaInfraSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, acaInfraSubnetName)
output privateEndpointSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
output ddosPlanResourceId string = enableDdosProtection ? ddosPlan.id : ''
output privateEndpointSubnetNsgResourceId string = enablePrivateEndpointSubnetNsg ? privateEndpointSubnetNsg.id : ''
