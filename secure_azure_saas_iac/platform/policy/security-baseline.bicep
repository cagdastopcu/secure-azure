// Resource-group scoped governance baseline.
// Uses Azure built-in policies for:
// - allowed regions
// - required tags with expected values
targetScope = 'resourceGroup'

@description('Location for policy assignment metadata.')
param location string = resourceGroup().location

@description('Allowed Azure regions for resource deployments.')
param allowedLocations array = [
  'westeurope'
]

@description('Environment tag value expected on resources.')
param environmentTagValue string

@description('Project tag value expected on resources.')
param projectTagValue string

@description('Managed-by tag value expected on resources.')
param managedByTagValue string = 'bicep'

var allowedLocationsPolicyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
var requireTagAndValuePolicyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/2a0e14a6-b0a6-4fab-991a-187a4f81c498'

// Restrict deployment geography to approved regions.
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

// Enforce environment tag consistency.
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

// Enforce project tag consistency.
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

// Enforce managedBy tag consistency.
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

// Expose assignment names for operations/reporting.
output policyAssignments array = [
  allowedLocationsAssignment.name
  requireEnvironmentTag.name
  requireProjectTag.name
  requireManagedByTag.name
]
