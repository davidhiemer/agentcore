# Hello World Agent

A minimal AgentCore container demonstrating the essential structure and requirements for building an agent.

## Purpose

This agent serves as:
- A starting point for understanding AgentCore container requirements
- A template for building new agents
- A simple test case for the deployment pipeline

## Features

- Minimal dependencies (just AWS SDK and logging)
- Structured JSON logging with structlog
- AWS X-Ray tracing support
- Health check endpoint
- Non-root container execution

## Quick Start

### Build the Container

```bash
# From this directory
docker build -t hello-world-agent .

# Or from the repository root
docker build -t hello-world-agent ./agents/hello-world
```

### Get the Image Digest

After building, get the SHA256 digest for Terraform configuration:

```bash
# Get the image ID (local digest)
docker inspect --format='{{.Id}}' hello-world-agent

# For pushed images, use the repo digest
docker inspect --format='{{index .RepoDigests 0}}' hello-world-agent
```

### Run Locally

```bash
# Interactive mode (runs a test invocation)
docker run --rm hello-world-agent

# With stdin input
echo '{"input_text": "Hello!", "session_id": "test-123", "agent_id": "hello-world"}' | \
  docker run --rm -i hello-world-agent
```

### Expected Output

```json
{
  "output_text": "Hello! I'm the Hello World Agent. How can I help you today?",
  "session_id": "test-123",
  "agent_name": "HelloWorldAgent",
  "agent_version": "1.0.0",
  "status": "success"
}
```

## Terraform Configuration

Once built and pushed to ECR, configure in your `terraform.tfvars`:

```hcl
agents = {
  "hello-world" = {
    name        = "Hello World Agent"
    description = "Minimal agent for testing and demonstration"
    
    # Replace with actual digest from your build
    runtime_version_digest = "sha256:abc123..."
    
    # Minimal permissions - only baseline required
    capability_bundles = [
      "baseline"
    ]
    
    additional_tags = {
      Team = "platform-engineering"
    }
  }
}
```

## Project Structure

```
hello-world/
├── Dockerfile          # Multi-stage container build
├── requirements.txt    # Python dependencies (pinned versions)
├── README.md          # This file
└── src/
    ├── __init__.py
    └── agent.py       # Agent implementation
```

## Customization Points

1. **Add capabilities**: Modify `requirements.txt` and add AWS service calls
2. **Change model integration**: Add Bedrock client for AI-powered responses
3. **Add state management**: Integrate DynamoDB for session persistence
4. **Enhance logging**: Add custom metrics or structured fields

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `INFO` | Logging verbosity |
| `AWS_XRAY_DAEMON_ADDRESS` | - | X-Ray daemon endpoint (enables tracing) |
| `AWS_REGION` | `us-east-1` | AWS region for SDK calls |

## Next Steps

For a more complete agent example with AWS integrations, see the [data-processor](../data-processor/) agent.

