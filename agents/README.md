# AgentCore Container Examples

This directory contains example agent containers that demonstrate how to build agents for the AgentCore platform.

## Overview

Agents in AgentCore run as containers. Each agent:
- Is packaged as a Docker container
- Has an immutable SHA256 digest used in Terraform configuration
- Runs with least-privilege IAM permissions via capability bundles
- Integrates with the AgentCore runtime for invocation

## Example Agents

| Agent | Description | Complexity | Key Features |
|-------|-------------|------------|--------------|
| [hello-world](./hello-world/) | Minimal agent | Simple | Basic structure, logging, health check |
| [data-processor](./data-processor/) | Full-featured agent | Advanced | DynamoDB, S3, Bedrock, session state |

## Quick Start

### 1. Build an Agent

```bash
# Build the hello-world agent
docker build -t hello-world-agent ./hello-world

# Build the data-processor agent  
docker build -t data-processor-agent ./data-processor
```

### 2. Get the Image Digest

The digest is required for the Terraform configuration:

```bash
# Get local image ID
docker inspect --format='{{.Id}}' hello-world-agent
# Output: sha256:a1b2c3d4e5f6789012345678901234567890abcdef...
```

### 3. Test Locally

```bash
# Run hello-world
echo '{"input_text": "Hello!", "session_id": "test", "agent_id": "hw"}' | \
  docker run --rm -i hello-world-agent

# Run data-processor (requires AWS credentials)
docker run --rm \
  -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_REGION \
  data-processor-agent
```

### 4. Configure in Terraform

Add the agent to your `terraform.tfvars`:

```hcl
agents = {
  "hello-world" = {
    name        = "Hello World Agent"
    description = "Minimal agent for testing"
    
    runtime_version_digest = "sha256:a1b2c3d4..."  # From step 2
    
    capability_bundles = ["baseline"]
    
    additional_tags = {
      Team = "platform-engineering"
    }
  }
}
```

## Container Requirements

### Base Image

Use a minimal, secure base image:

```dockerfile
FROM python:3.12-slim
```

### Non-Root User

Always run as non-root:

```dockerfile
RUN groupadd -r agent && useradd -r -g agent agent
USER agent
```

### Health Check

Include a health check for container orchestration:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import src.agent; print('healthy')" || exit 1
```

### Entry Point

Use a Python module entry point:

```dockerfile
ENTRYPOINT ["python", "-m", "src.agent"]
```

### Labels

Add OCI labels for traceability:

```dockerfile
LABEL org.opencontainers.image.title="My Agent"
LABEL org.opencontainers.image.source="https://github.com/bank/agentcore"
```

## Pinned Dependencies

Always pin dependency versions for reproducible builds:

```txt
# requirements.txt
boto3==1.34.34
structlog==24.1.0
```

## Request/Response Format

### Input Event

Agents receive JSON events via stdin:

```json
{
  "input_text": "User's message",
  "session_id": "unique-session-id",
  "agent_id": "agent-identifier",
  "user_context": {},
  "tool_inputs": {}
}
```

### Output Response

Agents return JSON responses to stdout:

```json
{
  "output_text": "Agent's response",
  "session_id": "unique-session-id",
  "agent_name": "AgentName",
  "agent_version": "1.0.0",
  "status": "success",
  "tool_results": {},
  "metadata": {}
}
```

## Build Pipeline

The recommended build flow:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Build     │────▶│    Sign     │────▶│   Push to   │
│  Container  │     │  (Cosign)   │     │ Artifactory │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                    ┌──────────────────────────┘
                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Copy to    │────▶│  Copy to    │────▶│  Copy to    │
│  Dev ECR    │     │ Preprod ECR │     │  Prod ECR   │
└─────────────┘     └─────────────┘     └─────────────┘
     (Auto)           (Approval)         (2 Approvals)
```

See [Artifact Promotion](../architecture/04-artifact-promotion.md) for GitHub Actions workflows.

## Capability Bundles

Agents are granted permissions via capability bundles:

| Bundle | Description |
|--------|-------------|
| `baseline` | CloudWatch Logs, X-Ray tracing |
| `dynamodb_readonly` | Read from DynamoDB tables |
| `dynamodb_readwrite` | Read/write DynamoDB tables |
| `s3_readonly` | Read from S3 buckets |
| `s3_readwrite` | Read/write S3 buckets |
| `secrets_readonly` | Read from Secrets Manager |
| `ssm_parameters_readonly` | Read SSM parameters |
| `kms_encrypt_decrypt` | KMS encryption operations |
| `sns_publish` | Publish to SNS topics |
| `sqs_send_receive` | Send/receive SQS messages |
| `lambda_invoke` | Invoke Lambda functions |
| `bedrock_invoke_model` | Invoke Bedrock models |

See [IAM Model](../architecture/06-iam-model.md) for details.

## Getting the Runtime Digest

### After Local Build

```bash
docker inspect --format='{{.Id}}' my-agent
```

### After Push to Registry

```bash
# The digest is returned when pushing
docker push my-registry/my-agent:latest
# Output includes: sha256:abc123...

# Or query the registry
docker manifest inspect my-registry/my-agent:latest | jq '.config.digest'
```

### From ECR

```bash
aws ecr describe-images \
  --repository-name agentcore/my-agent \
  --query 'imageDetails[0].imageDigest' \
  --output text
```

## Local Development

### Without AWS

Both agents can run without AWS credentials for basic testing:

```bash
docker run --rm hello-world-agent
```

### With LocalStack

For full integration testing:

```bash
# Start LocalStack
docker run -d --name localstack \
  -p 4566:4566 \
  localstack/localstack

# Run agent with LocalStack endpoint
docker run --rm \
  -e AWS_ENDPOINT_URL=http://host.docker.internal:4566 \
  -e AWS_ACCESS_KEY_ID=test \
  -e AWS_SECRET_ACCESS_KEY=test \
  data-processor-agent
```

## Creating a New Agent

1. **Copy the template**
   ```bash
   cp -r hello-world my-new-agent
   ```

2. **Modify the agent code**
   - Edit `src/agent.py` with your logic
   - Update `requirements.txt` with dependencies
   - Update the Dockerfile if needed

3. **Build and test**
   ```bash
   docker build -t my-new-agent ./my-new-agent
   docker run --rm my-new-agent
   ```

4. **Get the digest and add to Terraform**
   ```bash
   docker inspect --format='{{.Id}}' my-new-agent
   ```

5. **Push through the promotion pipeline**
   - Push to Artifactory
   - Promote to Dev ECR
   - Test in Dev
   - Promote to Preprod/Prod

## Troubleshooting

### Container won't start

Check the health check:
```bash
docker run --rm --entrypoint python my-agent -c "import src.agent; print('ok')"
```

### Permission denied errors

Ensure the Dockerfile:
- Creates the non-root user correctly
- Sets file ownership before switching users
- Switches to non-root user after copying files

### Missing AWS credentials

The agent needs AWS credentials. In local dev:
```bash
docker run -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY my-agent
```

In AgentCore, credentials are provided by the execution role.

