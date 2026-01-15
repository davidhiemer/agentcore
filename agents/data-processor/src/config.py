"""
Data Processor Agent - Configuration

Configuration is loaded from environment variables with sensible defaults.
This pattern allows the same container to run in different environments
(dev, preprod, prod) with different configurations.
"""

import os
from pydantic_settings import BaseSettings


class AgentConfig(BaseSettings):
    """
    Agent configuration loaded from environment variables.
    
    Environment variables are prefixed with AGENT_ for clarity.
    Example: AGENT_AWS_REGION=us-east-1
    """
    
    # AWS Configuration
    aws_region: str = os.environ.get("AWS_REGION", "us-east-1")
    
    # DynamoDB Configuration
    dynamodb_table: str = os.environ.get(
        "AGENT_DYNAMODB_TABLE",
        "agentcore-data-processor"
    )
    session_table: str = os.environ.get(
        "AGENT_SESSION_TABLE",
        "agentcore-sessions"
    )
    
    # S3 Configuration
    s3_bucket: str = os.environ.get(
        "AGENT_S3_BUCKET",
        "agentcore-data"
    )
    
    # Bedrock Configuration
    bedrock_model_id: str = os.environ.get(
        "AGENT_BEDROCK_MODEL",
        "anthropic.claude-3-sonnet-20240229-v1:0"
    )
    
    # Logging Configuration
    log_level: str = os.environ.get("LOG_LEVEL", "INFO")
    
    # Operational limits
    max_processing_items: int = int(os.environ.get(
        "AGENT_MAX_ITEMS",
        "1000"
    ))
    request_timeout_seconds: int = int(os.environ.get(
        "AGENT_REQUEST_TIMEOUT",
        "30"
    ))
    
    class Config:
        env_prefix = "AGENT_"
        case_sensitive = False

