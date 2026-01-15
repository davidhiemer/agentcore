"""
Hello World Agent - Minimal AgentCore Implementation

This module demonstrates the minimum viable structure for an AgentCore agent.
It shows how to:
1. Set up structured logging
2. Handle agent invocation events
3. Return properly formatted responses
4. Integrate with AWS X-Ray for tracing

The agent responds to simple greeting requests, demonstrating the request/response
pattern used by AgentCore.
"""

import json
import os
import sys
from typing import Any

import structlog
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

# ==============================================================================
# Logging Configuration
# ==============================================================================

structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger(__name__)

# ==============================================================================
# X-Ray Tracing Configuration
# ==============================================================================

# Only enable X-Ray if running in AWS environment
if os.environ.get("AWS_XRAY_DAEMON_ADDRESS"):
    patch_all()
    xray_recorder.configure(
        service="hello-world-agent",
        streaming_threshold=5,
        context_missing="LOG_ERROR"
    )


# ==============================================================================
# Agent Handler
# ==============================================================================

class HelloWorldAgent:
    """
    Minimal agent implementation demonstrating AgentCore integration.
    
    This agent responds to greeting requests with personalized responses.
    It serves as a template for understanding the basic agent lifecycle.
    """
    
    def __init__(self):
        self.name = "HelloWorldAgent"
        self.version = "1.0.0"
        logger.info(
            "agent_initialized",
            name=self.name,
            version=self.version
        )
    
    def handle(self, event: dict[str, Any]) -> dict[str, Any]:
        """
        Main handler for agent invocation.
        
        Args:
            event: The invocation event containing:
                - input_text: The user's input message
                - session_id: Unique session identifier
                - agent_id: The agent's identifier
                - Additional context as needed
        
        Returns:
            Response dict containing:
                - output_text: The agent's response
                - session_attributes: Any session state to preserve
                - Additional metadata
        """
        logger.info(
            "agent_invoked",
            session_id=event.get("session_id"),
            agent_id=event.get("agent_id")
        )
        
        try:
            input_text = event.get("input_text", "")
            session_id = event.get("session_id", "unknown")
            
            # Process the input
            response_text = self._generate_response(input_text)
            
            result = {
                "output_text": response_text,
                "session_id": session_id,
                "agent_name": self.name,
                "agent_version": self.version,
                "status": "success"
            }
            
            logger.info(
                "agent_response_generated",
                session_id=session_id,
                status="success"
            )
            
            return result
            
        except Exception as e:
            logger.exception(
                "agent_error",
                error=str(e),
                session_id=event.get("session_id")
            )
            return {
                "output_text": "I encountered an error processing your request.",
                "status": "error",
                "error_type": type(e).__name__
            }
    
    def _generate_response(self, input_text: str) -> str:
        """
        Generate a response based on input text.
        
        This is a simple demonstration - real agents would integrate
        with Bedrock models, databases, or external services.
        """
        input_lower = input_text.lower()
        
        if "hello" in input_lower or "hi" in input_lower:
            return "Hello! I'm the Hello World Agent. How can I help you today?"
        
        if "name" in input_lower:
            return f"My name is {self.name}, version {self.version}."
        
        if "help" in input_lower:
            return (
                "I'm a simple demonstration agent. I can respond to greetings "
                "and tell you my name. I'm here to show the basic structure of "
                "an AgentCore container."
            )
        
        if "status" in input_lower or "health" in input_lower:
            return "I'm running smoothly! All systems operational."
        
        return (
            f"You said: '{input_text}'. I'm a minimal agent, so my responses "
            "are limited. Try saying 'hello' or ask for 'help'!"
        )


# ==============================================================================
# Entry Point
# ==============================================================================

def main():
    """
    Main entry point for the agent container.
    
    In the AgentCore runtime, this would be invoked by the container orchestration
    system. For local testing, events can be passed via stdin or command-line args.
    """
    logger.info("agent_starting")
    
    agent = HelloWorldAgent()
    
    # Check if input is provided via stdin (for testing)
    if not sys.stdin.isatty():
        try:
            event = json.load(sys.stdin)
            result = agent.handle(event)
            print(json.dumps(result, indent=2))
        except json.JSONDecodeError as e:
            logger.error("invalid_json_input", error=str(e))
            sys.exit(1)
    else:
        # Interactive mode for local development
        logger.info("interactive_mode", message="No stdin input, running test")
        test_event = {
            "input_text": "Hello, agent!",
            "session_id": "test-session-001",
            "agent_id": "hello-world"
        }
        result = agent.handle(test_event)
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

