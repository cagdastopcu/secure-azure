// -----------------------------------------------------------------------------
// FILE: Network baseline module (VNet, subnets, optional DDoS/NSG).
// USED IN SAAS FLOW: Provides subnet IDs required by app/data stamps.
// SECURITY-CRITICAL: Defines private boundaries and inbound filtering posture.
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
@description('If true, deploy Azure Firewall and force ACA subnet outbound traffic through it for controlled egress inspection.')
param enableAzureFirewallForEgress bool = false
@description('CIDR for Azure Firewall subnet. Azure requires a dedicated subnet named AzureFirewallSubnet, typically at least /26.')
param azureFirewallSubnetPrefix string = '10.40.3.0/26'
@description('Azure Firewall SKU tier. Standard is baseline; Premium enables advanced TLS inspection/IDPS features.')
@allowed([
  'Standard'
  'Premium'
])
param azureFirewallSkuTier string = 'Standard'
@description('Threat intel mode for Azure Firewall policy. Deny blocks known malicious IPs/domains, Alert logs only.')
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param azureFirewallThreatIntelMode string = 'Deny'

// Core VNet name that groups all subnets for this environment.
var vnetName = '${projectPrefix}-${environment}-vnet'
// Dedicated subnet used by ACA control/data plane components.
var acaInfraSubnetName = 'snet-aca-infra'
// Dedicated subnet for Private Endpoints to keep private ingress centralized.
var privateEndpointSubnetName = 'snet-private-endpoints'
// Azure reserved subnet name for Azure Firewall data plane.
var azureFirewallSubnetName = 'AzureFirewallSubnet'
// Optional DDoS plan name when internet-facing protections are required.
var ddosPlanName = '${projectPrefix}-${environment}-ddos-plan'
// NSG attached to PE subnet to make traffic intent explicit and auditable.
var peNsgName = '${projectPrefix}-${environment}-pe-nsg'
// Firewall policy centralizes L3-L7 inspection settings and future rule collections.
var firewallPolicyName = '${projectPrefix}-${environment}-fw-policy'
// Firewall resource name for this environment.
var firewallName = '${projectPrefix}-${environment}-fw'
// Static public IP is required for Azure Firewall internet egress path.
var firewallPublicIpName = '${projectPrefix}-${environment}-fw-pip'
// Route table that forces outbound internet traffic to traverse Azure Firewall.
var acaEgressRouteTableName = '${projectPrefix}-${environment}-aca-egress-rt'
// Optional firewall subnet block used when firewall egress mode is turned on.
var optionalFirewallSubnet = enableAzureFirewallForEgress ? [
  {
    // Azure Firewall deployment requires subnet name exactly AzureFirewallSubnet.
    name: azureFirewallSubnetName
    properties: {
      // /26 or larger is recommended by Azure Firewall guidance.
      addressPrefix: azureFirewallSubnetPrefix
    }
  }
] : []

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

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-09-01' = if (enableAzureFirewallForEgress) {
  // Policy name lets security teams find and govern this firewall profile across environments.
  name: firewallPolicyName
  // Deploy in same region as VNet to reduce cross-region control/data dependencies.
  location: location
  // Inherit platform tags so cost ownership and environment tracking stay consistent.
  tags: tags
  properties: {
    // Security hardening: Deny is strongest known-bad posture; Alert is available when teams need observe-only rollout.
    threatIntelMode: azureFirewallThreatIntelMode
    // Security hardening: DNS proxy helps enforce FQDN/network rules consistently at firewall.
    dnsSettings: {
      enableProxy: true
      requireProxyForNetworkRules: false
    }
  }
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = if (enableAzureFirewallForEgress) {
  // Public IP name is used by downstream allowlists and troubleshooting workflows.
  name: firewallPublicIpName
  // Keep Public IP in same region as firewall resource.
  location: location
  // Tag for governance and cost attribution.
  tags: tags
  sku: {
    // Azure Firewall requires Standard Public IP SKU for production-supported deployment.
    name: 'Standard'
  }
  properties: {
    // Static allocation keeps egress identity stable for partner allowlists/auditing.
    publicIPAllocationMethod: 'Static'
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
    // Build subnet list in one place so optional firewall subnet can be injected only when enabled.
    subnets: concat([
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
    ], optionalFirewallSubnet)
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-09-01' = if (enableAzureFirewallForEgress) {
  // Firewall resource name identifies this egress control point in dashboards and alerts.
  name: firewallName
  // Co-locate firewall with workload VNet for low-latency egress control.
  location: location
  // Apply common governance tags.
  tags: tags
  properties: {
    // Security hardening: bind to Firewall Policy so central security team can manage rules independently.
    firewallPolicy: {
      id: firewallPolicy.id
    }
    sku: {
      // SKU name AZFW_VNet is required for VNet-based Azure Firewall deployments.
      name: 'AZFW_VNet'
      // Tier controls feature set (Standard/Premium).
      tier: azureFirewallSkuTier
    }
    ipConfigurations: [
      {
        name: 'fw-ipconfig'
        properties: {
          // Must point to subnet named AzureFirewallSubnet.
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, azureFirewallSubnetName)
          }
          // Public IP provides controlled internet egress identity.
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
    // Security hardening: duplicate threat intel mode at firewall instance level for explicit enforcement.
    threatIntelMode: azureFirewallThreatIntelMode
  }
}

resource acaEgressRouteTable 'Microsoft.Network/routeTables@2023-09-01' = if (enableAzureFirewallForEgress) {
  // Route table name reflects purpose: ACA subnet outbound traffic steering.
  name: acaEgressRouteTableName
  // Route table lives in same region and resource group scope as the VNet.
  location: location
  // Carry governance tags.
  tags: tags
  properties: {
    // Keep BGP propagation enabled unless you intentionally isolate from dynamic routes.
    disableBgpRoutePropagation: false
    routes: [
      {
        // Default route sends all internet-bound traffic to Azure Firewall for egress control.
        name: 'default-egress-via-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          // Firewall private IP becomes the secure egress choke point.
          nextHopIpAddress: firewall!.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

resource acaInfraSubnetWithFirewallRoute 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = if (enableAzureFirewallForEgress) {
  // Update existing ACA subnet by referencing parent VNet/subnet path.
  name: '${vnet.name}/${acaInfraSubnetName}'
  properties: {
    // Keep subnet CIDR and delegation unchanged while adding forced egress route.
    addressPrefix: acaInfraSubnetPrefix
    routeTable: {
      // Attach route table so subnet uses firewall as default internet next hop.
      id: acaEgressRouteTable.id
    }
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

output vnetName string = vnet.name
// Subnet resource IDs are consumed by stamp modules for delegated/private networking.
output acaInfraSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, acaInfraSubnetName)
output privateEndpointSubnetResourceId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
output ddosPlanResourceId string = enableDdosProtection ? ddosPlan.id : ''
output privateEndpointSubnetNsgResourceId string = enablePrivateEndpointSubnetNsg ? privateEndpointSubnetNsg.id : ''
// Returned so operations can target firewall object directly for rule/policy troubleshooting.
output azureFirewallResourceId string = enableAzureFirewallForEgress ? firewall.id : ''
// Returned so route-table inspections can confirm expected firewall private next hop.
output azureFirewallPrivateIp string = enableAzureFirewallForEgress ? firewall!.properties.ipConfigurations[0].properties.privateIPAddress : ''
// Returned so security automation can discover and validate the attached firewall policy.
output azureFirewallPolicyResourceId string = enableAzureFirewallForEgress ? firewallPolicy.id : ''
// Returned for auditing egress public identity and external allowlist workflows.
output azureFirewallPublicIpResourceId string = enableAzureFirewallForEgress ? firewallPublicIp.id : ''
// Returned to validate that ACA subnet is attached to forced-egress route table.
output acaEgressRouteTableResourceId string = enableAzureFirewallForEgress ? acaEgressRouteTable.id : ''
