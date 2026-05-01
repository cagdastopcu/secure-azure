// Governance baseline at resource-group scope.
// Why: enforce location and tagging standards automatically.
targetScope = 'resourceGroup'

@description('Location for policy assignment metadata resources.')
param location string = resourceGroup().location

@description('Allowed deployment regions.')
param allowedLocations array = [
  'westeurope'
]

@description('Expected environment tag value on resources.')
param environmentTagValue string

@description('Expected project tag value on resources.')
param projectTagValue string

@description('Expected managedBy tag value on resources.')
param managedByTagValue string = 'bicep'

// Built-in policy IDs (verify periodically in tenant).
var allowedLocationsPolicyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
var requireTagAndValuePolicyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/2a0e14a6-b0a6-4fab-991a-187a4f81c498'

resource allowedLocationsAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'alz-allowed-locations'
  location: location
  properties: {
    displayName: 'Allow deployments only in approved regions'
    description: 'Restricts resource creation to an approved list of Azure regions.'
    policyDefinitionId: allowedLocationsPolicyDefinitionId
    enforcementMode: 'Default'
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
  }
}

resource requireEnvironmentTag 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'alz-require-environment-tag'
  location: location
  properties: {
    displayName: 'Require environment tag and value'
    description: 'Ensures all resources include the expected environment tag value.'
    policyDefinitionId: requireTagAndValuePolicyDefinitionId
    enforcementMode: 'Default'
    parameters: {
      tagName: {
        value: 'environment'
      }
      tagValue: {
        value: environmentTagValue
      }
    }
  }
}

resource requireProjectTag 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'alz-require-project-tag'
  location: location
  properties: {
    displayName: 'Require project tag and value'
    description: 'Ensures all resources include the expected project tag value.'
    policyDefinitionId: requireTagAndValuePolicyDefinitionId
    enforcementMode: 'Default'
    parameters: {
      tagName: {
        value: 'project'
      }
      tagValue: {
        value: projectTagValue
      }
    }
  }
}

resource requireManagedByTag 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'alz-require-managedby-tag'
  location: location
  properties: {
    displayName: 'Require managedBy tag and value'
    description: 'Ensures all resources include the expected managedBy tag value.'
    policyDefinitionId: requireTagAndValuePolicyDefinitionId
    enforcementMode: 'Default'
    parameters: {
      tagName: {
        value: 'managedBy'
      }
      tagValue: {
        value: managedByTagValue
      }
    }
  }
}

output policyAssignments array = [
  allowedLocationsAssignment.name
  requireEnvironmentTag.name
  requireProjectTag.name
  requireManagedByTag.name
]
