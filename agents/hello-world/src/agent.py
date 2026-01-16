"""
Minimal AgentCore Runtime Agent
This is a simple test agent for validating infrastructure.
"""

import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    AgentCore runtime handler.
    
    Args:
        event: The incoming event from AgentCore
        context: Lambda context object
        
    Returns:
        Response dict with agent output
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Extract the user input
    user_input = event.get("input", {}).get("text", "Hello!")
    
    # Simple echo response for testing
    response = {
        "output": {
            "text": f"Hello from AgentCore! You said: {user_input}"
        },
        "metadata": {
            "agent_name": "hello-world",
            "version": "1.0.0"
        }
    }
    
    logger.info(f"Returning response: {json.dumps(response)}")
    return response


