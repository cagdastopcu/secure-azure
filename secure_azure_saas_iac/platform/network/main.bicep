// -----------------------------------------------------------------------------
// GLOSSARY + SAAS CONTEXT (DEEP PLAIN-LANGUAGE)
// - IaC: This file defines cloud behavior as auditable text instead of manual clicks.
// - Module: Reusable building block with inputs (parameters) and outputs.
// - Parameter: Value you change per environment without rewriting deployment logic.
// - Resource: Actual Azure service instance created by this file.
// - Output: Exported value used by other modules, tests, or pipeline steps.
// - Identity-first: Prefer managed identities over embedded static credentials.
// - Private-first: Prefer private networking and explicit ingress boundaries.
// - How this file is used in this SaaS project:
//   1. Creates VNet and subnets for runtime and private endpoints.
//   2. Used before app/data modules so subnet IDs are available.
//   3. Inputs: CIDRs, DDOS toggle, PE subnet NSG toggle.
//   4. Outputs: subnet resource IDs consumed by other modules.
//   5. Security role: network isolation and deny-by-default boundaries.
// -----------------------------------------------------------------------------
// Network baseline for the SaaS stamp.
// Why: explicit private boundaries for runtime and private endpoints.
targetScope = 'resourceGroup'

@description('Azure region where network resources are deployed.')
param location string
@description('Project prefix used in network resource names.')
param projectPrefix string
@description('Environment label (dev/test/prod) used in names.')
param environment string
@description('Address space CIDR for the primary virtual network.')
param vnetAddressPrefix string
@description('Subnet CIDR delegated to Azure Container Apps infrastructure.')
param acaInfraSubnetPrefix string
@description('Subnet CIDR reserved for Private Endpoint NICs.')
param privateEndpointSubnetPrefix string
@description('Common tags applied to all network resources.')
param tags object = {}
@description('If true, create and attach a DDoS Network Protection plan to this VNet.')
param enableDdosProtection bool = false
@description('If true, attach NSG to private endpoint subnet for explicit network boundary control.')
param enablePrivateEndpointSubnetNsg bool = true

// Core VNet name that groups all subnets for this environment.
var vnetName = '${projectPrefix}-${environment}-vnet'
// Dedicated subnet used by ACA control/data plane components.
var acaInfraSubnetName = 'snet-aca-infra'
// Dedicated subnet for Private Endpoints to keep private ingress centralized.
var privateEndpointSubnetName = 'snet-private-endpoints'
// Optional DDoS plan name when internet-facing protections are required.
var ddosPlanName = '${projectPrefix}-${environment}-ddos-plan'
// NSG attached to PE subnet to make traffic intent explicit and auditable.
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
          // Lower number means higher priority; this rule should be evaluated early.
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
          // Required for Azure platform health probes in many topologies.
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
          // Keep deny rule lower priority than required allow rules above.
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
// Subnet resource IDs are consumed by stamp modules for delegated/private networking.
output acaInfraSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, acaInfraSubnetName)
output privateEndpointSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
output ddosPlanResourceId string = enableDdosProtection ? ddosPlan.id : ''
output privateEndpointSubnetNsgResourceId string = enablePrivateEndpointSubnetNsg ? privateEndpointSubnetNsg.id : ''
