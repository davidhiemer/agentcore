# Data Processor Agent

A full-featured AgentCore container demonstrating production patterns including AWS service integrations, state management, and AI-powered analysis.

## Purpose

This agent demonstrates:
- DynamoDB integration for data persistence
- S3 operations for file handling
- Bedrock integration for AI analysis
- Comprehensive error handling
- Full observability with structured logging and X-Ray
- Session state management
- Tool-based architecture

## Features

| Feature | Description |
|---------|-------------|
| **Data Storage** | Store and retrieve structured data via DynamoDB |
| **File Processing** | Read files from S3 for analysis |
| **AI Analysis** | Use Bedrock models to analyze loaded data |
| **Session Management** | Persistent session state across invocations |
| **Observability** | Structured logging, X-Ray tracing, metrics |

## Quick Start

### Build the Container

```bash
# From this directory
docker build -t data-processor-agent .

# Or from the repository root
docker build -t data-processor-agent ./agents/data-processor
```

### Get the Image Digest

```bash
# Get the image digest for Terraform configuration
docker inspect --format='{{.Id}}' data-processor-agent

# Example output: sha256:a1b2c3d4e5f6...
```

### Run Locally (with AWS credentials)

```bash
# Set required environment variables
export AWS_REGION=us-east-1
export AGENT_DYNAMODB_TABLE=agentcore-data-processor
export AGENT_SESSION_TABLE=agentcore-sessions
export AGENT_S3_BUCKET=agentcore-data

# Run with AWS credentials
docker run --rm \
  -e AWS_REGION \
  -e AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY \
  -e AGENT_DYNAMODB_TABLE \
  -e AGENT_SESSION_TABLE \
  -e AGENT_S3_BUCKET \
  data-processor-agent
```

### Example Invocations

**Get Help:**
```bash
echo '{"input_text": "help", "session_id": "session-001", "agent_id": "data-processor"}' | \
  docker run --rm -i data-processor-agent
```

**Store Data:**
```bash
echo '{
  "input_text": "store this data",
  "session_id": "session-001",
  "agent_id": "data-processor",
  "tool_inputs": {
    "data": {
      "title": "Q4 Report",
      "metrics": {"revenue": 1000000, "growth": 15.5}
    }
  }
}' | docker run --rm -i data-processor-agent
```

**Retrieve Data:**
```bash
echo '{
  "input_text": "retrieve the report",
  "session_id": "session-001",
  "agent_id": "data-processor",
  "tool_inputs": {
    "item_id": "uuid-from-store-response"
  }
}' | docker run --rm -i data-processor-agent
```

**Analyze Data (requires Bedrock access):**
```bash
echo '{
  "input_text": "analyze this data and summarize the trends",
  "session_id": "session-001",
  "agent_id": "data-processor"
}' | docker run --rm -i data-processor-agent
```

## Terraform Configuration

### Agent Definition

```hcl
agents = {
  "data-processor" = {
    name        = "Data Processor Agent"
    description = "Processes and analyzes data with AWS integrations"
    
    # Replace with actual digest from your build
    runtime_version_digest = "sha256:xyz789..."
    
    # Required capability bundles
    capability_bundles = [
      "baseline",           # CloudWatch logs, basic permissions
      "dynamodb_readwrite", # DynamoDB access for data storage
      "s3_readwrite",       # S3 access for file operations
      "bedrock_invoke_model" # Bedrock for AI analysis
    ]
    
    # Increase memory for data processing workloads
    memory_mb_override = 1024
    
    additional_tags = {
      Team        = "data-engineering"
      CostCenter  = "data-platform"
    }
  }
}
```

### Required AWS Resources

The agent expects these DynamoDB tables (you may need to create them separately or add to your Terraform):

```hcl
# Data storage table
resource "aws_dynamodb_table" "data_processor" {
  name         = "agentcore-data-processor"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  
  attribute {
    name = "id"
    type = "S"
  }
  
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

# Session state table
resource "aws_dynamodb_table" "sessions" {
  name         = "agentcore-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  
  attribute {
    name = "session_id"
    type = "S"
  }
  
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}
```

## Project Structure

```
data-processor/
├── Dockerfile          # Multi-stage container build
├── requirements.txt    # Python dependencies (pinned versions)
├── README.md          # This file
├── config/
│   └── settings.json  # Default configuration
└── src/
    ├── __init__.py
    ├── agent.py       # Main agent implementation
    ├── config.py      # Configuration management
    └── tools.py       # Tool registry (DynamoDB, S3, Bedrock)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Processor Agent                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │  Request     │───▶│   Agent      │───▶│  Response    │   │
│  │  Validation  │    │   Handler    │    │  Builder     │   │
│  └──────────────┘    └──────┬───────┘    └──────────────┘   │
│                             │                                │
│                      ┌──────┴───────┐                        │
│                      │ Tool Registry │                        │
│                      └──────┬───────┘                        │
│         ┌───────────────────┼───────────────────┐            │
│         ▼                   ▼                   ▼            │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │  DynamoDB    │    │     S3       │    │   Bedrock    │   │
│  │   Tools      │    │    Tools     │    │    Tools     │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
   │  DynamoDB    │    │     S3       │    │   Bedrock    │
   │  Tables      │    │   Bucket     │    │    Model     │
   └──────────────┘    └──────────────┘    └──────────────┘
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region |
| `AGENT_DYNAMODB_TABLE` | `agentcore-data-processor` | Data storage table |
| `AGENT_SESSION_TABLE` | `agentcore-sessions` | Session state table |
| `AGENT_S3_BUCKET` | `agentcore-data` | S3 bucket for files |
| `AGENT_BEDROCK_MODEL` | `anthropic.claude-3-sonnet-20240229-v1:0` | Bedrock model ID |
| `LOG_LEVEL` | `INFO` | Logging verbosity |
| `AGENT_MAX_ITEMS` | `1000` | Max items to process |
| `AGENT_REQUEST_TIMEOUT` | `30` | Request timeout seconds |

## Capability Bundles

This agent requires the following IAM capability bundles:

| Bundle | Purpose |
|--------|---------|
| `baseline` | CloudWatch Logs, X-Ray, basic permissions |
| `dynamodb_readwrite` | Read/write access to agent's DynamoDB tables |
| `s3_readwrite` | Read/write access to agent's S3 bucket |
| `bedrock_invoke_model` | Invoke Bedrock foundation models |

## Observability

### Logging

All logs are structured JSON via structlog:

```json
{
  "event": "agent_invoked",
  "session_id": "session-001",
  "agent_id": "data-processor",
  "timestamp": "2025-01-15T10:30:00.000Z",
  "level": "info"
}
```

### X-Ray Tracing

When `AWS_XRAY_DAEMON_ADDRESS` is set, all AWS SDK calls are traced:
- DynamoDB operations
- S3 operations  
- Bedrock invocations

### Metrics

Key metrics are logged and can be extracted to CloudWatch:
- `processing_time_ms` - Request processing duration
- `session_turn` - Number of turns in session
- Tool execution outcomes

## Error Handling

The agent handles errors gracefully:

| Error Type | Handling |
|------------|----------|
| Validation errors | Return structured error with field details |
| AWS errors | Log with error code, return user-friendly message |
| Unexpected errors | Log exception, return generic error message |

## Testing

### Unit Tests

```bash
# Install dev dependencies
pip install pytest pytest-asyncio moto

# Run tests
pytest tests/
```

### Integration Tests

```bash
# Build the container
docker build -t data-processor-agent:test .

# Run with localstack for AWS services
docker-compose -f docker-compose.test.yml up
```

## Extending the Agent

### Adding a New Tool

1. Add the method to `src/tools.py`:

```python
def my_new_tool(self, param1: str, param2: int) -> dict[str, Any]:
    """Tool description."""
    logger.info("executing_my_tool", param1=param1)
    # Implementation
    return {"status": "success", "result": ...}
```

2. Call from the agent handler in `src/agent.py`

### Adding New AWS Integrations

1. Add client initialization in `DataProcessorAgent._init_aws_clients()`
2. Pass to ToolRegistry
3. Add capability bundle to Terraform configuration

## Related Documentation

- [Hello World Agent](../hello-world/) - Minimal agent example
- [Artifact Promotion](../../architecture/04-artifact-promotion.md) - Build and deploy workflow
- [IAM Model](../../architecture/06-iam-model.md) - Capability bundles reference

