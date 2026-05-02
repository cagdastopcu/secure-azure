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
//   1. Deploys Front Door + WAF edge stack.
//   2. Used when public SaaS endpoints require protected internet entry.
//   3. Inputs: origin hostname and naming context.
//   4. Outputs: endpoint hostname and WAF policy ID.
//   5. Security role: central WAF filtering and HTTPS edge control.
// -----------------------------------------------------------------------------
// Optional secure edge module: Azure Front Door + WAF.
// Why: adds global edge protection and central web filtering in front of public endpoints.
targetScope = 'resourceGroup'

@description('Deployment region for metadata resources (Front Door is global service).')
param location string

@description('Project prefix used in naming.')
param projectPrefix string

@description('Environment label for naming.')
param environment string

@description('Public origin host (for example ACA web app FQDN).')
param originHostName string

@description('Tags to apply.')
param tags object = {}

// Front Door profile: top-level global container for endpoint/origin/waf route objects.
var profileName = '${projectPrefix}-${environment}-afd'
// Endpoint: public DNS hostname served by Azure Front Door.
var endpointName = '${projectPrefix}-${environment}-ep'
// Origin group: health/latency policy for backend origins.
var originGroupName = 'primary-origins'
// Origin object: actual backend target (ACA FQDN here).
var originName = 'aca-web-origin'
// Route: maps incoming paths/protocols to origin group.
var routeName = 'default-route'
// WAF policy: central managed rules and enforcement mode.
var wafPolicyName = '${projectPrefix}-${environment}-waf'

resource afdProfile 'Microsoft.Cdn/profiles@2024-09-01' = {
  name: profileName
  location: 'global'
  sku: {
    // Premium unlocks private link origin, advanced WAF and enterprise features.
    name: 'Premium_AzureFrontDoor'
  }
  tags: tags
}

resource wafPolicy 'Microsoft.Network/frontDoorWebApplicationFirewallPolicies@2024-02-01' = {
  name: wafPolicyName
  location: location
  tags: tags
  properties: {
    policySettings: {
      // Prevention mode actively blocks matched malicious patterns.
      mode: 'Prevention'
      enabledState: 'Enabled'
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
        }
      ]
    }
  }
}

resource afdEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-09-01' = {
  parent: afdProfile
  name: endpointName
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2024-09-01' = {
  parent: afdProfile
  name: originGroupName
  properties: {
    healthProbeSettings: {
      // Probe path should be lightweight and always available.
      probePath: '/'
      probeProtocol: 'Https'
      probeRequestType: 'HEAD'
      probeIntervalInSeconds: 120
    }
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
  }
}

resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2024-09-01' = {
  parent: originGroup
  name: originName
  properties: {
    hostName: originHostName
    // Enforce TLS from Front Door to origin.
    httpsPort: 443
    // HTTP port is defined for completeness; forwarding policy below still enforces HTTPS-only to clients.
    httpPort: 80
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    originHostHeader: originHostName
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2024-09-01' = {
  parent: afdProfile
  name: 'waf-security-policy'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: afdEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-09-01' = {
  parent: afdEndpoint
  name: routeName
  properties: {
    originGroup: {
      id: originGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    // Redirect all client traffic to HTTPS at the edge.
    httpsRedirect: 'Enabled'
    linkToDefaultDomain: 'Enabled'
    enabledState: 'Enabled'
  }
}

output frontDoorEndpointHostName string = afdEndpoint.properties.hostName
output frontDoorProfileName string = afdProfile.name
output wafPolicyResourceId string = wafPolicy.id
