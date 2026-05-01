# Workload Service Modules

This folder now contains reusable secure service modules:

- `api-service.bicep`
  - HTTP API Container App
  - Public ingress is opt-in (`enablePublicIngress=false` by default)
  - HTTPS enforced (`allowInsecure=false`)
  - Managed identity wiring

- `tenant-onboarding.bicep`
  - Internal-only Container App for tenant provisioning workflows
  - Managed identity wiring
  - HTTPS enforced

- `jobs/queue-processor.bicep`
  - Container Apps Job for queue-driven background processing
  - Event trigger for Azure Service Bus queue
  - Managed identity-based scaler auth

## Usage Notes

- Pass existing ACA managed environment resource ID from your stamp.
- Use user-assigned identities with least-privilege RBAC on dependent resources.
- Keep onboarding/worker services internal unless external exposure is required.
- Prefer Key Vault references for secrets in application runtime code.
