# Workload Service Modules

This folder contains reusable workload modules that run inside Azure Container Apps.
These modules are intended to be composed on top of the platform and stamp modules.

## What Is a Workload Module

A workload module is a service-level template that defines:
- runtime container settings
- ingress exposure pattern
- identity wiring
- scaling behavior
- environment variable contract

It does not recreate shared platform resources like VNet, Log Analytics, or Key Vault.

## Modules in This Folder

### `api-service.bicep`

Purpose:
- Deploys a tenant-facing HTTP API as a Container App.

Security posture:
- Public ingress is opt-in (`enablePublicIngress=false` by default).
- HTTPS enforced (`allowInsecure=false`).
- User-assigned managed identity is attached for cloud access without static secrets.

How it works:
- Receives existing `managedEnvironmentId`.
- Creates one Container App.
- Injects `AZURE_CLIENT_ID` and optional `KEYVAULT_URI`.
- Optionally accepts extra env vars via `extraEnv`.

### `tenant-onboarding.bicep`

Purpose:
- Deploys an internal provisioning service used for tenant lifecycle workflows.

Security posture:
- Ingress is internal-only (`external: false`).
- HTTPS enforced.
- User-assigned identity attached.

How it works:
- Similar runtime model to API module, but no public ingress mode.
- Intended for orchestration and control-plane style business workflows.

### `jobs/queue-processor.bicep`

Purpose:
- Deploys an event-driven background worker using Container Apps Jobs.

Security posture:
- No public HTTP ingress surface.
- Service Bus trigger auth uses managed identity pattern.
- Retry and timeout controls bound runaway processing behavior.

How it works:
- Trigger type is `Event`.
- Scale rule watches Service Bus queue depth.
- Job runs worker container with configured parallelism/timeout/retry controls.

## Key Terms (Beginner Friendly)

- `Container App`: Long-running service endpoint or worker process managed by Azure.
- `Container App Job`: Event/schedule-driven execution unit, usually for background tasks.
- `Managed Environment`: Shared runtime boundary where Container Apps and Jobs run.
- `User-assigned Managed Identity`: Reusable identity object you attach to apps/jobs.
- `Service Bus Queue`: Durable message queue for asynchronous processing.
- `Scale Rule`: Condition that tells ACA when to scale replicas/executions.

## Integration Contract

Expected inputs from platform/stamp layer:
- `managedEnvironmentId`
- `userAssignedIdentityResourceId`
- `userAssignedIdentityClientId`
- service-specific settings (image, port, queue, limits)

Expected surrounding dependencies:
- Key Vault access RBAC for identity
- Data-plane access RBAC (Service Bus, Storage, SQL, etc.) for identity
- Private networking and DNS from underlying stamp

## Recommended Usage Pattern

1. Deploy `main.bicep` (platform + stamps).
2. Capture outputs for environment and identity IDs.
3. Deploy workload module(s) using those IDs.
4. Grant least-privilege RBAC to identity per service dependency.
5. Validate telemetry and security controls before production traffic.
