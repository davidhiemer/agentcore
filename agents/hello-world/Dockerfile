# Minimal AgentCore Runtime Container
# This is a simple test agent for validating the infrastructure

FROM public.ecr.aws/lambda/python:3.11

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy agent code
COPY src/ ${LAMBDA_TASK_ROOT}/

# Set the handler
CMD ["agent.handler"]


