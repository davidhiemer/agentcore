# Runbook

## Overview

This runbook provides operational procedures for the AgentCore platform. All procedures are designed for auditability and compliance with banking regulatory requirements.

---

## Table of Contents

1. [Promotion Procedures](#1-promotion-procedures)
2. [Rollback Procedures](#2-rollback-procedures)
3. [Incident Response](#3-incident-response)
4. [Audit Evidence Collection](#4-audit-evidence-collection)

---

## 1. Promotion Procedures

### 1.1 Promote to Dev

**Trigger**: New build available in Artifactory
**Approval**: Auto-approve or Platform Engineer
**SLA**: < 30 minutes from build completion

#### Steps

1. **Verify Build Artifacts**
   ```bash
   # Check image exists in Artifactory
   crane manifest artifactory.bank.com/agentcore/agent@sha256:<DIGEST>
   
   # Verify signature
   cosign verify \
     --certificate-identity-regexp=".*github.com/bank/agentcore.*" \
     --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
     artifactory.bank.com/agentcore/agent@sha256:<DIGEST>
   
   # Check SBOM attestation
   cosign verify-attestation \
     --type spdxjson \
     artifactory.bank.com/agentcore/agent@sha256:<DIGEST>
   ```

2. **Trigger Promotion Workflow**
   ```bash
   gh workflow run promote-dev.yml -f digest=sha256:<DIGEST>
   ```

3. **Verify ECR Image**
   ```bash
   aws ecr describe-images \
     --repository-name agentcore/agent \
     --image-ids imageDigest=sha256:<DIGEST> \
     --profile dev
   ```

4. **Update Terraform**
   ```hcl
   # examples/dev/terraform.tfvars
   agents = {
     "my-agent" = {
       runtime_version_digest = "sha256:<NEW_DIGEST>"
       # ...
     }
   }
   ```

5. **Apply Terraform**
   ```bash
   cd examples/dev
   terraform plan -out=plan.tfplan
   # Review plan output
   terraform apply plan.tfplan
   ```

6. **Verify Deployment**
   ```bash
   # Check endpoint is serving new version
   aws bedrock-agent get-agent-runtime-endpoint \
     --agent-runtime-endpoint-id <ENDPOINT_ID> \
     --profile dev
   ```

#### Rollback Trigger
- Build verification fails
- Terraform apply fails
- Smoke tests fail

---

### 1.2 Promote to Preprod

**Trigger**: Successful dev deployment + testing
**Approval**: Tech Lead (required)
**SLA**: Within 2 business days of dev deployment

#### Prerequisites Checklist

- [ ] Image deployed to dev for at least 4 hours
- [ ] Dev smoke tests passed
- [ ] No open P1/P2 issues related to this version
- [ ] Change request approved (if required)

#### Steps

1. **Verify Dev Deployment**
   ```bash
   # Check image exists in Dev ECR
   aws ecr describe-images \
     --repository-name agentcore/agent \
     --image-ids imageDigest=sha256:<DIGEST> \
     --profile dev
   
   # Check deployment time (minimum 4 hours ago)
   aws ecr describe-images \
     --repository-name agentcore/agent \
     --image-ids imageDigest=sha256:<DIGEST> \
     --query 'imageDetails[0].imagePushedAt' \
     --profile dev
   ```

2. **Create Promotion Request**
   ```bash
   gh workflow run promote-preprod.yml -f digest=sha256:<DIGEST>
   ```

3. **Await Tech Lead Approval**
   - GitHub Environment protection rule requires approval
   - Approver reviews digest, SBOM, and dev test results

4. **Verify ECR Image (Post-Approval)**
   ```bash
   aws ecr describe-images \
     --repository-name agentcore/agent \
     --image-ids imageDigest=sha256:<DIGEST> \
     --profile preprod
   ```

5. **Update Terraform and Apply**
   ```bash
   cd examples/preprod
   # Update terraform.tfvars with new digest
   terraform plan -out=plan.tfplan
   terraform apply plan.tfplan
   ```

6. **Execute Preprod Test Suite**
   ```bash
   # Run integration tests against preprod
   ./scripts/integration-tests.sh --env preprod --agent my-agent
   ```

#### Evidence to Record
- Promotion workflow run ID
- Approver identity
- Terraform plan output
- Test results

---

### 1.3 Promote to Prod

**Trigger**: Successful preprod deployment + soak period
**Approval**: Platform Team Lead AND Security Team (required)
**SLA**: Within 1 business week of preprod deployment

#### Prerequisites Checklist

- [ ] Image deployed to preprod for at least 24 hours
- [ ] Preprod integration tests passed
- [ ] Preprod performance baseline acceptable
- [ ] Security scan completed (no critical/high findings)
- [ ] Change request approved
- [ ] Rollback plan documented
- [ ] Communication sent to stakeholders

#### Steps

1. **Verify Preprod Soak Period**
   ```bash
   # Check preprod deployment time (minimum 24 hours ago)
   DEPLOYED_AT=$(aws ecr describe-images \
     --repository-name agentcore/agent \
     --image-ids imageDigest=sha256:<DIGEST> \
     --query 'imageDetails[0].imagePushedAt' \
     --output text \
     --profile preprod)
   
   # Calculate hours since deployment
   DEPLOYED_EPOCH=$(date -d "${DEPLOYED_AT}" +%s)
   NOW_EPOCH=$(date +%s)
   SOAK_HOURS=$(( (NOW_EPOCH - DEPLOYED_EPOCH) / 3600 ))
   echo "Soak time: ${SOAK_HOURS} hours"
   
   # Must be >= 24
   if [ ${SOAK_HOURS} -lt 24 ]; then
     echo "ERROR: Insufficient soak time"
     exit 1
   fi
   ```

2. **Verify No Active Incidents**
   ```bash
   # Check PagerDuty for open incidents
   # Check Splunk for error spikes
   # Review CloudWatch alarms
   ```

3. **Create Promotion Request**
   ```bash
   gh workflow run promote-prod.yml -f digest=sha256:<DIGEST>
   ```

4. **Await Dual Approval**
   - Platform Team Lead reviews technical readiness
   - Security Team reviews security posture
   - Both approvals required to proceed

5. **Execute Production Deployment**
   ```bash
   cd examples/prod
   # Update terraform.tfvars with new digest
   terraform plan -out=plan.tfplan
   
   # IMPORTANT: Save plan for audit
   terraform show -json plan.tfplan > plan.json
   aws s3 cp plan.json s3://bank-audit-evidence/deployments/prod/<DIGEST>/terraform-plan.json
   
   # Apply with explicit approval
   terraform apply plan.tfplan
   ```

6. **Post-Deployment Verification**
   ```bash
   # Verify endpoint
   aws bedrock-agent get-agent-runtime-endpoint \
     --agent-runtime-endpoint-id <ENDPOINT_ID> \
     --profile prod
   
   # Run smoke tests
   ./scripts/smoke-tests.sh --env prod --agent my-agent
   
   # Monitor for 15 minutes
   ./scripts/monitor-deployment.sh --env prod --duration 15m
   ```

7. **Record Deployment Evidence**
   ```bash
   cat > deployment-record.json << EOF
   {
     "digest": "sha256:<DIGEST>",
     "environment": "prod",
     "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
     "deployed_by": "$(whoami)",
     "approvers": ["platform-lead", "security-team"],
     "terraform_plan_hash": "$(sha256sum plan.json | cut -d' ' -f1)",
     "change_request": "CHG-123456"
   }
   EOF
   aws s3 cp deployment-record.json \
     s3://bank-audit-evidence/deployments/prod/<DIGEST>/deployment-record.json
   ```

---

## 2. Rollback Procedures

### 2.1 Immediate Rollback (Emergency)

**Trigger**: Critical production issue
**Authorization**: On-call engineer (no approval required for P1)
**SLA**: < 15 minutes

#### Steps

1. **Identify Previous Working Digest**
   ```bash
   # List recent images in prod ECR
   aws ecr describe-images \
     --repository-name agentcore/agent \
     --query 'imageDetails | sort_by(@, &imagePushedAt) | reverse(@) | [0:5]' \
     --profile prod
   
   # Previous known-good digest should be documented
   ROLLBACK_DIGEST="sha256:<PREVIOUS_KNOWN_GOOD>"
   ```

2. **Update Terraform**
   ```bash
   cd examples/prod
   
   # Update to previous digest
   sed -i 's/runtime_version_digest = "sha256:.*"/runtime_version_digest = "'${ROLLBACK_DIGEST}'"/' terraform.tfvars
   
   # Plan and apply
   terraform plan -out=rollback.tfplan
   terraform apply rollback.tfplan
   ```

3. **Verify Rollback**
   ```bash
   # Confirm endpoint is serving previous version
   aws bedrock-agent get-agent-runtime-endpoint \
     --agent-runtime-endpoint-id <ENDPOINT_ID> \
     --profile prod
   
   # Run smoke tests
   ./scripts/smoke-tests.sh --env prod --agent my-agent
   ```

4. **Document Rollback**
   ```bash
   cat > rollback-record.json << EOF
   {
     "from_digest": "sha256:<FAILED_DIGEST>",
     "to_digest": "${ROLLBACK_DIGEST}",
     "environment": "prod",
     "rolled_back_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
     "rolled_back_by": "$(whoami)",
     "reason": "P1 incident - <BRIEF_DESCRIPTION>",
     "incident_id": "INC-123456"
   }
   EOF
   aws s3 cp rollback-record.json \
     s3://bank-audit-evidence/rollbacks/prod/$(date +%Y%m%d%H%M%S)/rollback-record.json
   ```

5. **Create Incident Ticket**
   - Record timeline
   - Record rollback digest
   - Assign RCA owner

---

### 2.2 Planned Rollback

**Trigger**: Scheduled rollback after issue resolution
**Authorization**: Platform Team Lead
**SLA**: During maintenance window

#### Steps

Follow the same procedure as Immediate Rollback, but:
- Obtain Platform Team Lead approval before execution
- Execute during scheduled maintenance window
- Notify stakeholders in advance
- Do not require P1 incident classification

---

## 3. Incident Response

### 3.1 Severity Definitions

| Severity | Definition | Response SLA | Resolution SLA |
|----------|------------|--------------|----------------|
| **P1 - Critical** | Complete service outage or data loss | 15 minutes | 4 hours |
| **P2 - High** | Major functionality degraded | 30 minutes | 8 hours |
| **P3 - Medium** | Minor functionality affected | 2 hours | 24 hours |
| **P4 - Low** | Cosmetic or minor issues | 8 hours | 5 business days |

---

### 3.2 P1 Incident Response

#### Initial Response (0-15 minutes)

1. **Acknowledge Alert**
   ```bash
   # PagerDuty acknowledgment
   pd incident ack <INCIDENT_ID>
   ```

2. **Assess Impact**
   ```bash
   # Check CloudWatch dashboard
   open "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=agentcore-prod-dashboard"
   
   # Check error rate
   aws cloudwatch get-metric-statistics \
     --namespace AgentCore/prod \
     --metric-name ErrorCount \
     --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
     --period 60 \
     --statistics Sum \
     --profile prod
   
   # Check Splunk for errors
   # Search: index=agentcore_prod level=ERROR | timechart count
   ```

3. **Identify Affected Agents**
   ```bash
   # Check which agents are erroring
   aws cloudwatch get-metric-data \
     --metric-data-queries file://error-query.json \
     --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
     --profile prod
   ```

4. **Open Incident Bridge**
   - Create Slack channel: #inc-agentcore-<DATE>
   - Page relevant team members
   - Start incident log

#### Diagnosis (15-30 minutes)

5. **Check Recent Changes**
   ```bash
   # Recent deployments
   aws s3 ls s3://bank-audit-evidence/deployments/prod/ --recursive | tail -10
   
   # Recent promotions
   gh run list --workflow=promote-prod.yml --limit 5
   ```

6. **Check Logs**
   ```bash
   # Recent errors in CloudWatch
   aws logs filter-log-events \
     --log-group-name /aws/agentcore/prod/<AGENT_NAME> \
     --filter-pattern '{ $.level = "ERROR" }' \
     --start-time $(date -u -d '30 minutes ago' +%s)000 \
     --limit 50 \
     --profile prod
   
   # X-Ray traces for errors
   aws xray get-trace-summaries \
     --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
     --filter-expression 'fault = true' \
     --profile prod
   ```

7. **Check Dependencies**
   ```bash
   # VPC endpoint health
   aws ec2 describe-vpc-endpoints \
     --filters "Name=tag:Environment,Values=prod" \
     --query 'VpcEndpoints[*].[ServiceName,State]' \
     --profile prod
   
   # NAT gateway status
   aws ec2 describe-nat-gateways \
     --filter "Name=tag:Environment,Values=prod" \
     --query 'NatGateways[*].[NatGatewayId,State]' \
     --profile prod
   ```

#### Mitigation (30-60 minutes)

8. **Execute Mitigation**

   If deployment-related:
   ```bash
   # Follow Immediate Rollback procedure (Section 2.1)
   ```
   
   If dependency-related:
   ```bash
   # Engage AWS Support for P1
   aws support create-case \
     --subject "P1: AgentCore dependency issue" \
     --service-code "bedrock" \
     --severity-code "critical" \
     --communication-body "Description of issue..." \
     --profile prod
   ```
   
   If capacity-related:
   ```bash
   # Scale if applicable (update scale_profile)
   # This may require expedited change approval
   ```

9. **Verify Mitigation**
   ```bash
   # Monitor error rate decrease
   watch -n 30 'aws cloudwatch get-metric-statistics \
     --namespace AgentCore/prod \
     --metric-name ErrorCount \
     --start-time $(date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%SZ) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
     --period 60 \
     --statistics Sum \
     --profile prod'
   ```

#### Resolution

10. **Close Incident**
    - Update PagerDuty status
    - Post summary to Slack channel
    - Create RCA ticket

11. **Document Timeline**
    ```bash
    cat > incident-timeline.json << EOF
    {
      "incident_id": "INC-123456",
      "severity": "P1",
      "start_time": "2025-01-15T10:30:00Z",
      "acknowledged_time": "2025-01-15T10:32:00Z",
      "mitigation_time": "2025-01-15T10:45:00Z",
      "resolution_time": "2025-01-15T11:00:00Z",
      "impact": "Agent invocations failing",
      "affected_agents": ["customer-support-agent"],
      "root_cause": "TBD - RCA pending",
      "mitigation_action": "Rolled back to sha256:abc...",
      "responders": ["oncall-engineer", "platform-lead"]
    }
    EOF
    aws s3 cp incident-timeline.json \
      s3://bank-audit-evidence/incidents/INC-123456/timeline.json
    ```

---

## 4. Audit Evidence Collection

### 4.1 Routine Audit Package

**Frequency**: Monthly
**Owner**: Platform Team

#### Evidence Checklist

- [ ] All deployments with approval records
- [ ] All promotions with approval records
- [ ] IAM role configurations
- [ ] Security group configurations
- [ ] VPC endpoint configurations
- [ ] Log retention verification
- [ ] Encryption configuration
- [ ] Access logs

#### Collection Script

```bash
#!/bin/bash
# collect-audit-evidence.sh

AUDIT_DATE=$(date +%Y-%m)
AUDIT_BUCKET="s3://bank-audit-evidence/monthly/${AUDIT_DATE}"

for ENV in dev preprod prod; do
  echo "Collecting evidence for ${ENV}..."
  
  # IAM roles
  aws iam list-roles \
    --query "Roles[?contains(RoleName, 'agentcore-${ENV}')]" \
    --profile ${ENV} > /tmp/iam-roles-${ENV}.json
  aws s3 cp /tmp/iam-roles-${ENV}.json ${AUDIT_BUCKET}/iam/roles-${ENV}.json
  
  # IAM policies
  for ROLE in $(jq -r '.[].RoleName' /tmp/iam-roles-${ENV}.json); do
    aws iam list-attached-role-policies --role-name ${ROLE} --profile ${ENV} > /tmp/policies-${ROLE}.json
    aws s3 cp /tmp/policies-${ROLE}.json ${AUDIT_BUCKET}/iam/policies-${ROLE}.json
  done
  
  # Security groups
  aws ec2 describe-security-groups \
    --filters "Name=tag:Environment,Values=${ENV}" \
    --profile ${ENV} > /tmp/security-groups-${ENV}.json
  aws s3 cp /tmp/security-groups-${ENV}.json ${AUDIT_BUCKET}/network/security-groups-${ENV}.json
  
  # VPC endpoints
  aws ec2 describe-vpc-endpoints \
    --filters "Name=tag:Environment,Values=${ENV}" \
    --profile ${ENV} > /tmp/vpc-endpoints-${ENV}.json
  aws s3 cp /tmp/vpc-endpoints-${ENV}.json ${AUDIT_BUCKET}/network/vpc-endpoints-${ENV}.json
  
  # ECR repositories
  aws ecr describe-repositories \
    --profile ${ENV} > /tmp/ecr-repos-${ENV}.json
  aws s3 cp /tmp/ecr-repos-${ENV}.json ${AUDIT_BUCKET}/ecr/repositories-${ENV}.json
  
  # Log groups
  aws logs describe-log-groups \
    --log-group-name-prefix /aws/agentcore/${ENV} \
    --profile ${ENV} > /tmp/log-groups-${ENV}.json
  aws s3 cp /tmp/log-groups-${ENV}.json ${AUDIT_BUCKET}/logs/log-groups-${ENV}.json
  
  # KMS keys
  aws kms list-keys --profile ${ENV} > /tmp/kms-keys-${ENV}.json
  aws s3 cp /tmp/kms-keys-${ENV}.json ${AUDIT_BUCKET}/encryption/kms-keys-${ENV}.json
done

# Terraform state summary (not full state - sensitive data)
for ENV in dev preprod prod; do
  cd examples/${ENV}
  terraform state list > /tmp/tf-state-list-${ENV}.txt
  aws s3 cp /tmp/tf-state-list-${ENV}.txt ${AUDIT_BUCKET}/terraform/state-list-${ENV}.txt
done

# Deployments this month
aws s3 sync \
  s3://bank-audit-evidence/deployments/ \
  /tmp/deployments/ \
  --exclude "*" \
  --include "*/${AUDIT_DATE}*"
aws s3 sync /tmp/deployments/ ${AUDIT_BUCKET}/deployments/

# Promotions this month
aws s3 sync \
  s3://bank-audit-evidence/promotions/ \
  /tmp/promotions/ \
  --exclude "*" \
  --include "*/${AUDIT_DATE}*"
aws s3 sync /tmp/promotions/ ${AUDIT_BUCKET}/promotions/

echo "Audit evidence collected to ${AUDIT_BUCKET}"
```

---

### 4.2 On-Demand Audit Request

**Trigger**: External audit request
**SLA**: 48 hours

#### Steps

1. **Receive and Log Request**
   ```bash
   cat > audit-request.json << EOF
   {
     "request_id": "AUDIT-2025-001",
     "requestor": "External Auditor Name",
     "request_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
     "scope": "Production AgentCore deployment January 2025",
     "evidence_requested": [
       "Deployment records",
       "Approval records",
       "Access logs",
       "Configuration snapshots"
     ]
   }
   EOF
   aws s3 cp audit-request.json s3://bank-audit-evidence/requests/AUDIT-2025-001/request.json
   ```

2. **Collect Requested Evidence**
   - Run collection script for specified scope
   - Generate Terraform plan snapshots
   - Export Splunk queries for log evidence

3. **Prepare Audit Package**
   ```bash
   # Create signed manifest
   cat > manifest.json << EOF
   {
     "audit_id": "AUDIT-2025-001",
     "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
     "generated_by": "$(whoami)",
     "files": [
       $(find /tmp/audit-evidence -type f -exec sha256sum {} \; | jq -Rs 'split("\n") | map(select(. != "") | split("  ") | {hash: .[0], file: .[1]}) | @json')
     ]
   }
   EOF
   
   # Sign manifest
   gpg --sign --armor manifest.json
   ```

4. **Deliver to Auditor**
   - Secure transfer via approved channel
   - Log delivery confirmation

---

### 4.3 Evidence Types Reference

| Evidence Type | Location | Retention | Format |
|--------------|----------|-----------|--------|
| Build manifests | `s3://bank-audit-evidence/builds/` | 7 years | JSON |
| Promotion records | `s3://bank-audit-evidence/promotions/` | 7 years | JSON |
| Deployment records | `s3://bank-audit-evidence/deployments/` | 7 years | JSON |
| Terraform plans | `s3://bank-audit-evidence/terraform/` | 7 years | JSON |
| Rollback records | `s3://bank-audit-evidence/rollbacks/` | 7 years | JSON |
| Incident timelines | `s3://bank-audit-evidence/incidents/` | 7 years | JSON |
| SBOMs | `s3://bank-audit-evidence/builds/*/sbom.spdx.json` | 7 years | SPDX JSON |
| Container signatures | Artifactory / ECR | Indefinite | Sigstore |
| CloudWatch Logs | CloudWatch | Per retention policy | JSON |
| Splunk Logs | Splunk | Per retention policy | JSON |
| CloudTrail | S3 (centralized) | 7 years | JSON |

---

## Appendix A: Quick Reference Commands

```bash
# Check agent status
aws bedrock-agent get-agent --agent-id <AGENT_ID> --profile <ENV>

# Check endpoint status
aws bedrock-agent get-agent-runtime-endpoint --agent-runtime-endpoint-id <ENDPOINT_ID> --profile <ENV>

# List recent ECR images
aws ecr describe-images --repository-name agentcore/agent --query 'imageDetails | sort_by(@, &imagePushedAt) | reverse(@) | [0:5]' --profile <ENV>

# Check CloudWatch alarm status
aws cloudwatch describe-alarms --alarm-name-prefix agentcore-<ENV> --state-value ALARM --profile <ENV>

# Get recent error logs
aws logs filter-log-events --log-group-name /aws/agentcore/<ENV>/<AGENT> --filter-pattern '{ $.level = "ERROR" }' --start-time $(date -u -d '1 hour ago' +%s)000 --profile <ENV>

# Check NAT gateway status
aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=<ENV>" --query 'NatGateways[*].[NatGatewayId,State]' --profile <ENV>

# Check VPC endpoint status
aws ec2 describe-vpc-endpoints --filters "Name=tag:Environment,Values=<ENV>" --query 'VpcEndpoints[*].[ServiceName,State]' --profile <ENV>

# Verify image signature
cosign verify --certificate-identity-regexp=".*github.com/bank/agentcore.*" --certificate-oidc-issuer=https://token.actions.githubusercontent.com <ECR_URL>@sha256:<DIGEST>
```

---

## Appendix B: Contact Escalation

| Role | Contact Method | When to Engage |
|------|---------------|----------------|
| On-Call Engineer | PagerDuty | All P1/P2 incidents |
| Platform Team Lead | Slack + Phone | P1 incidents, Production changes |
| Security Team | Slack #security-oncall | Security incidents, Prod approvals |
| AWS Support | AWS Console | AWS service issues |
| Change Management | ServiceNow | Emergency changes |

