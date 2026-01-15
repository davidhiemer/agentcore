# ==============================================================================
# Hello World Agent - Minimal AgentCore Container
# ==============================================================================
# This is a minimal agent demonstrating the base requirements for an AgentCore
# container. It includes the essential dependencies and structure needed for
# the agent runtime to function.
#
# BUILD:
#   docker build -t hello-world-agent .
#
# GET DIGEST:
#   docker inspect --format='{{index .Id}}' hello-world-agent
# ==============================================================================

FROM python:3.12-slim AS base

# Security: Run as non-root user
RUN groupadd -r agent && useradd -r -g agent agent

# Install security updates
RUN apt-get update && \
    apt-get upgrade -y && \
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

# Set ownership
RUN chown -R agent:agent /app

# Switch to non-root user
USER agent

# ==============================================================================
# Runtime Configuration
# ==============================================================================

# Environment variables for AgentCore runtime
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV LOG_LEVEL=INFO

# Health check for container orchestration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import src.agent; print('healthy')" || exit 1

# Entry point for AgentCore invocation
ENTRYPOINT ["python", "-m", "src.agent"]

# ==============================================================================
# Labels for traceability
# ==============================================================================
LABEL org.opencontainers.image.title="Hello World Agent"
LABEL org.opencontainers.image.description="Minimal AgentCore agent for demonstration"
LABEL org.opencontainers.image.vendor="CPE Platform Engineering"
LABEL org.opencontainers.image.source="https://github.com/bank/agentcore"

