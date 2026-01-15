# ==============================================================================
# Data Processor Agent - Full-Featured AgentCore Container
# ==============================================================================
# This agent demonstrates more advanced functionality including:
# - DynamoDB integration for data persistence
# - S3 operations for file processing
# - Bedrock integration for AI-powered analysis
# - Structured error handling and observability
#
# BUILD:
#   docker build -t data-processor-agent .
#
# GET DIGEST:
#   docker inspect --format='{{index .Id}}' data-processor-agent
# ==============================================================================

FROM python:3.12-slim AS base

# Security: Run as non-root user
RUN groupadd -r agent && useradd -r -g agent agent

# Install security updates and required system packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ==============================================================================
# Dependencies Stage
# ==============================================================================
FROM base AS dependencies

# Copy requirements first for better layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# ==============================================================================
# Application Stage
# ==============================================================================
FROM dependencies AS application

# Copy application code
COPY src/ ./src/
COPY config/ ./config/

# Create directories for runtime data
RUN mkdir -p /app/data /app/logs && \
    chown -R agent:agent /app

# Switch to non-root user
USER agent

# ==============================================================================
# Runtime Configuration
# ==============================================================================

# Environment variables for AgentCore runtime
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV LOG_LEVEL=INFO
ENV AGENT_DATA_DIR=/app/data
ENV AGENT_CONFIG_DIR=/app/config

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "from src.agent import DataProcessorAgent; print('healthy')" || exit 1

# Entry point for AgentCore invocation
ENTRYPOINT ["python", "-m", "src.agent"]

# ==============================================================================
# Labels for traceability
# ==============================================================================
LABEL org.opencontainers.image.title="Data Processor Agent"
LABEL org.opencontainers.image.description="Full-featured AgentCore agent with AWS integrations"
LABEL org.opencontainers.image.vendor="CPE Platform Engineering"
LABEL org.opencontainers.image.source="https://github.com/bank/agentcore"

