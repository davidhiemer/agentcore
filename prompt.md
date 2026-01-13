You are an AWS platform architect designing a production-ready Amazon Bedrock AgentCore platform across three AWS accounts (dev, preprod, prod). Each account is “prod-like” and must be architecturally identical; only sizing/scale knobs may vary per account. We are a bank and require high auditability, least privilege, and deterministic behavior. Infrastructure should all be in Terraform

Core architectural constraint (very important):
- We are building ONE Terraform module that represents the entire AgentCore platform.
- All functionality (runtime, endpoints, networking attachments, IAM, observability, future gateway/memory) MUST be implemented as internal submodules. Each feature should be its own submodule
- Consumers must never compose multiple modules to build the platform.
- Environment differences must be expressed ONLY via variables (especially a scale_profile object).
- Code must be DRY: no copy/paste per environment, no duplicated logic, no env-specific forks.

Module structure expectations (scaffolding, not full spec):

- We are building ONE root Terraform module: `cpe_agentcore`. CPE stands for Cloud Platform Engineering, our platform team name.
- This root module contains INTERNAL submodules only (not separately consumable).
- Submodules exist to organize concerns and enforce DRY code, not to expose public interfaces.

Terraform quality expectations:
- Use strong typing for all variables.
- Use variable validation blocks for invariants and guardrails.
- Prefer locals for normalization and derived values.
- Avoid count-based resource toggling where for_each with maps is clearer.
- Avoid implicit dependencies; use explicit inputs/outputs between submodules.
- All resources must be taggable and tagged consistently.
- Explicitly define provider blocks and version constraints.
- Use awscc only where required for AgentCore runtime/endpoint resources.
- Use aws provider for all supporting infrastructure.
- Provide an example Terraform directory structure for the root module and internal submodules.

Dependency expectations:
- Submodules must have clear dependency ordering (e.g., network → iam → runtime → endpoints).
- Outputs from one submodule must be explicitly passed as inputs to dependents.
- Avoid shared global state or implicit cross-submodule references.

At a minimum, assume the following internal submodules (names illustrative):
- ecr                : per-account ECR repositories and policies
- network            : VPC attachments, NAT strategy (per-AZ vs single), VPC endpoints, private DNS
- iam                : execution roles, baseline + capability bundles, permission boundaries
- runtime            : AgentCore Runtime resources (VPC-attached)
- endpoints          : AgentCore Runtime Endpoints (pinned versions/digests)
- observability      : CloudWatch logs/metrics/alarms + Splunk forwarding
- gateway (future)   : tool governance and connectivity (feature-flagged)
- memory (future)    : AgentCore Memory (feature-flagged)

Rules:
- Submodules MUST NOT be deployable on their own.
- The root module orchestrates all dependencies.
- Environment parity is enforced by design.
- Environment differences are expressed ONLY via variables (especially `scale_profile`).
- No environment-specific modules, no duplicated resources, no conditional forks per env.


Non-negotiables:
- Do NOT replace AgentCore Runtime with EKS, ECS, or Lambda.
- Do NOT rebuild artifacts per environment.
- Do NOT collapse environments into Terraform workspaces.
- Do NOT create separate “dev/prod” modules.
- Assume all accounts are long-lived, production-grade, and independently auditable.

Hard requirements (locked):
- Use VPC-attached AgentCore Runtime. VPC is created outside the module; the module accepts VPC inputs (vpc_id, subnets, security groups).
- Artifact source-of-truth is Artifactory (authoritative). Promotion is COPY BY DIGEST only.
- Each AWS account has Terraform-managed ECR repositories.
- NAT strategy: prod and preprod use NAT per AZ (3 NAT gateways); dev uses a single NAT gateway.
- Start with open egress via NAT.
- Keep AWS service traffic internal using VPC endpoints.
- Cross-account invocation is required; calls must remain internal using recommended interface endpoint + private DNS patterns.
- IAM: one execution role per agent per env, baseline + opt-in capability bundles.
- Endpoint strategy: per-env runtime endpoints pinned to explicit runtime versions/digests; rollback is manual.
- Observability baseline: CloudWatch logs/metrics/alarms/traces; logs forwarded to Splunk.
- CI/CD: GitHub Actions with approval gates for promotions and Terraform applies.
- Terraform state: one state per environment/account (dev/preprod/prod).
- Provider strategy: awscc for AgentCore runtime/endpoint resources; aws provider for supporting infra and future gateway/memory.

Reasoning guidance:
- Prefer auditability over convenience.
- Prefer explicit promotion over implicit automation.
- Prefer least privilege and blast-radius isolation.
- Prefer deterministic, explainable designs suitable for auditors.
- When multiple valid designs exist, choose the one that minimizes long-term operational risk.

You must produce:

1) Final target architecture
   - Mermaid diagram
   - Show cross-account callers, VPC-attached runtime, interface endpoints + private DNS,
     NAT-per-AZ vs single NAT, CloudWatch + Splunk flow, and Artifactory → ECR promotion.

2) Terraform module design (critical)
   - ONE root module with clearly defined internal submodules.
   - Submodules MUST NOT be independently consumable.
   - Explicit variable contract (inputs/outputs).
   - Use locals to normalize inputs and enforce DRY patterns.
   - All environment differences expressed through:
     - environment identifier
     - scale_profile object
   - No duplicated resources or conditional forks per environment.

3) scale_profile schema
   - Include common sizing knobs (network, observability, concurrency, tool execution, retention).
   - Explicitly include NAT mode (per_az vs single).
   - Demonstrate dev vs preprod/prod differences using ONLY scale_profile.
   - Include terraform variable validation to prevent architectural drift.

4) Artifactory → ECR promotion design
   - Digest-copy flow
   - GitHub Actions gates and approvals
   - IAM roles and least-privilege policies
   - How unapproved digests are prevented from deployment
   - Provenance and audit trail (SBOM, attestations, evidence retention)

5) Network design
   - Required subnet-by-AZ input shapes
   - NAT-per-AZ vs single NAT logic
   - Baseline VPC endpoint list (AgentCore + core AWS services)
   - AZ-count tuning for interface endpoints

6) IAM model
   - Baseline execution role
   - Example capability bundles
   - Permission boundary strategy

7) Observability
   - Log JSON schema (audit-friendly)
   - Dashboards, alarms, and SLOs
   - Splunk forwarding approach

8) Runbook outline
   - Promotion
   - Rollback
   - Incident response
   - Audit evidence collection

For each major design choice, include:
- “Why this choice”
- “Why not the primary alternative”
