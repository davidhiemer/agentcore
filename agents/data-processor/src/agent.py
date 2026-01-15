"""
Data Processor Agent - Full-Featured AgentCore Implementation

This module demonstrates a production-ready agent with:
1. DynamoDB integration for state management
2. S3 operations for file processing
3. Bedrock integration for AI-powered analysis
4. Comprehensive error handling
5. Full observability with structured logging and X-Ray

The agent can process data files, store results, and provide AI-assisted analysis.
"""

import json
import os
import sys
from datetime import datetime, timezone
from typing import Any
from decimal import Decimal

import boto3
import structlog
from botocore.exceptions import ClientError
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all
from pydantic import BaseModel, ValidationError

from .config import AgentConfig
from .tools import ToolRegistry

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

if os.environ.get("AWS_XRAY_DAEMON_ADDRESS"):
    patch_all()
    xray_recorder.configure(
        service="data-processor-agent",
        streaming_threshold=5,
        context_missing="LOG_ERROR"
    )


# ==============================================================================
# Request/Response Models
# ==============================================================================

class AgentRequest(BaseModel):
    """Validated request model for agent invocations."""
    input_text: str
    session_id: str
    agent_id: str = "data-processor"
    user_context: dict[str, Any] = {}
    tool_inputs: dict[str, Any] = {}


class AgentResponse(BaseModel):
    """Structured response model."""
    output_text: str
    session_id: str
    agent_name: str
    agent_version: str
    status: str
    tool_results: dict[str, Any] = {}
    metadata: dict[str, Any] = {}


# ==============================================================================
# Data Processor Agent
# ==============================================================================

class DataProcessorAgent:
    """
    Production-ready agent with AWS service integrations.
    
    This agent demonstrates:
    - Reading/writing to DynamoDB for session state
    - Processing files from S3
    - Invoking Bedrock models for AI analysis
    - Tool execution with proper error handling
    """
    
    def __init__(self):
        self.name = "DataProcessorAgent"
        self.version = "1.0.0"
        self.config = AgentConfig()
        
        # Initialize AWS clients
        self._init_aws_clients()
        
        # Initialize tool registry
        self.tools = ToolRegistry(
            dynamodb=self.dynamodb,
            s3=self.s3,
            bedrock=self.bedrock
        )
        
        logger.info(
            "agent_initialized",
            name=self.name,
            version=self.version,
            region=self.config.aws_region
        )
    
    def _init_aws_clients(self):
        """Initialize AWS service clients with proper configuration."""
        session = boto3.Session(region_name=self.config.aws_region)
        
        self.dynamodb = session.resource("dynamodb")
        self.s3 = session.client("s3")
        self.bedrock = session.client("bedrock-runtime")
        
        logger.debug("aws_clients_initialized")
    
    def handle(self, event: dict[str, Any]) -> dict[str, Any]:
        """
        Main handler for agent invocation.
        
        Args:
            event: The invocation event from AgentCore runtime
        
        Returns:
            Structured response with results and metadata
        """
        start_time = datetime.now(timezone.utc)
        
        try:
            # Validate request
            request = AgentRequest(**event)
            
            logger.info(
                "agent_invoked",
                session_id=request.session_id,
                agent_id=request.agent_id
            )
            
            # Load session state
            session_state = self._load_session_state(request.session_id)
            
            # Process the request
            result = self._process_request(request, session_state)
            
            # Save updated session state
            self._save_session_state(request.session_id, session_state)
            
            # Build response
            response = AgentResponse(
                output_text=result["output_text"],
                session_id=request.session_id,
                agent_name=self.name,
                agent_version=self.version,
                status="success",
                tool_results=result.get("tool_results", {}),
                metadata={
                    "processing_time_ms": (
                        datetime.now(timezone.utc) - start_time
                    ).total_seconds() * 1000,
                    "session_turn": session_state.get("turn_count", 1)
                }
            )
            
            logger.info(
                "agent_response_generated",
                session_id=request.session_id,
                status="success",
                processing_time_ms=response.metadata["processing_time_ms"]
            )
            
            return response.model_dump()
            
        except ValidationError as e:
            logger.warning("validation_error", errors=e.errors())
            return self._error_response(
                "Invalid request format",
                "ValidationError",
                event.get("session_id", "unknown")
            )
            
        except ClientError as e:
            error_code = e.response["Error"]["Code"]
            logger.error(
                "aws_error",
                error_code=error_code,
                error=str(e),
                session_id=event.get("session_id")
            )
            return self._error_response(
                f"AWS service error: {error_code}",
                "AWSError",
                event.get("session_id", "unknown")
            )
            
        except Exception as e:
            logger.exception(
                "agent_error",
                error=str(e),
                session_id=event.get("session_id")
            )
            return self._error_response(
                "Internal error processing request",
                type(e).__name__,
                event.get("session_id", "unknown")
            )
    
    def _process_request(
        self,
        request: AgentRequest,
        session_state: dict[str, Any]
    ) -> dict[str, Any]:
        """
        Process the user request and execute appropriate tools.
        """
        input_lower = request.input_text.lower()
        tool_results = {}
        
        # Increment turn counter
        session_state["turn_count"] = session_state.get("turn_count", 0) + 1
        
        # Route to appropriate handler based on intent
        if "analyze" in input_lower or "process" in input_lower:
            output_text, tool_results = self._handle_analysis(request, session_state)
        
        elif "store" in input_lower or "save" in input_lower:
            output_text, tool_results = self._handle_storage(request, session_state)
        
        elif "retrieve" in input_lower or "get" in input_lower or "fetch" in input_lower:
            output_text, tool_results = self._handle_retrieval(request, session_state)
        
        elif "list" in input_lower or "show" in input_lower:
            output_text, tool_results = self._handle_list(request, session_state)
        
        elif "help" in input_lower:
            output_text = self._get_help_text()
        
        elif "status" in input_lower:
            output_text = self._get_status(session_state)
        
        else:
            output_text = (
                f"I received your request: '{request.input_text}'. "
                "I'm the Data Processor Agent. I can help you analyze data, "
                "store information, and retrieve records. Say 'help' for more options."
            )
        
        return {
            "output_text": output_text,
            "tool_results": tool_results
        }
    
    def _handle_analysis(
        self,
        request: AgentRequest,
        session_state: dict[str, Any]
    ) -> tuple[str, dict]:
        """Handle data analysis requests using Bedrock."""
        logger.info("handling_analysis", session_id=request.session_id)
        
        # Check if there's data to analyze
        if "current_data" not in session_state:
            return (
                "No data loaded for analysis. Please retrieve or upload data first.",
                {"analysis": {"status": "no_data"}}
            )
        
        try:
            # Use Bedrock for analysis (demonstrating integration)
            result = self.tools.analyze_data(
                data=session_state["current_data"],
                prompt=request.input_text
            )
            
            session_state["last_analysis"] = result
            
            return (
                f"Analysis complete: {result['summary']}",
                {"analysis": result}
            )
            
        except Exception as e:
            logger.error("analysis_failed", error=str(e))
            return (
                f"Analysis encountered an error: {str(e)}",
                {"analysis": {"status": "error", "error": str(e)}}
            )
    
    def _handle_storage(
        self,
        request: AgentRequest,
        session_state: dict[str, Any]
    ) -> tuple[str, dict]:
        """Handle data storage requests to DynamoDB."""
        logger.info("handling_storage", session_id=request.session_id)
        
        data_to_store = request.tool_inputs.get("data", {})
        
        if not data_to_store:
            return (
                "No data provided to store. Include data in the tool_inputs field.",
                {"storage": {"status": "no_data"}}
            )
        
        try:
            result = self.tools.store_data(
                table_name=self.config.dynamodb_table,
                data=data_to_store,
                session_id=request.session_id
            )
            
            return (
                f"Data stored successfully with ID: {result['item_id']}",
                {"storage": result}
            )
            
        except Exception as e:
            logger.error("storage_failed", error=str(e))
            return (
                f"Storage error: {str(e)}",
                {"storage": {"status": "error", "error": str(e)}}
            )
    
    def _handle_retrieval(
        self,
        request: AgentRequest,
        session_state: dict[str, Any]
    ) -> tuple[str, dict]:
        """Handle data retrieval from DynamoDB or S3."""
        logger.info("handling_retrieval", session_id=request.session_id)
        
        item_id = request.tool_inputs.get("item_id")
        s3_key = request.tool_inputs.get("s3_key")
        
        try:
            if s3_key:
                # Retrieve from S3
                result = self.tools.get_s3_object(
                    bucket=self.config.s3_bucket,
                    key=s3_key
                )
                session_state["current_data"] = result["content"]
                return (
                    f"Retrieved file from S3: {s3_key}",
                    {"retrieval": result}
                )
            
            elif item_id:
                # Retrieve from DynamoDB
                result = self.tools.get_data(
                    table_name=self.config.dynamodb_table,
                    item_id=item_id
                )
                session_state["current_data"] = result["data"]
                return (
                    f"Retrieved data for ID: {item_id}",
                    {"retrieval": result}
                )
            
            else:
                return (
                    "Please specify either 'item_id' or 's3_key' in tool_inputs.",
                    {"retrieval": {"status": "missing_params"}}
                )
                
        except Exception as e:
            logger.error("retrieval_failed", error=str(e))
            return (
                f"Retrieval error: {str(e)}",
                {"retrieval": {"status": "error", "error": str(e)}}
            )
    
    def _handle_list(
        self,
        request: AgentRequest,
        session_state: dict[str, Any]
    ) -> tuple[str, dict]:
        """Handle list/show requests."""
        logger.info("handling_list", session_id=request.session_id)
        
        try:
            items = self.tools.list_recent_items(
                table_name=self.config.dynamodb_table,
                session_id=request.session_id,
                limit=10
            )
            
            if items:
                item_list = "\n".join([
                    f"- {item['id']}: {item.get('title', 'Untitled')}"
                    for item in items
                ])
                return (
                    f"Found {len(items)} recent items:\n{item_list}",
                    {"list": {"items": items, "count": len(items)}}
                )
            else:
                return (
                    "No items found for this session.",
                    {"list": {"items": [], "count": 0}}
                )
                
        except Exception as e:
            logger.error("list_failed", error=str(e))
            return (
                f"Error listing items: {str(e)}",
                {"list": {"status": "error", "error": str(e)}}
            )
    
    def _load_session_state(self, session_id: str) -> dict[str, Any]:
        """Load session state from DynamoDB."""
        try:
            table = self.dynamodb.Table(self.config.session_table)
            response = table.get_item(Key={"session_id": session_id})
            
            if "Item" in response:
                logger.debug("session_state_loaded", session_id=session_id)
                return response["Item"].get("state", {})
            
            logger.debug("new_session", session_id=session_id)
            return {}
            
        except ClientError as e:
            logger.warning(
                "session_load_failed",
                session_id=session_id,
                error=str(e)
            )
            return {}
    
    def _save_session_state(self, session_id: str, state: dict[str, Any]) -> None:
        """Save session state to DynamoDB."""
        try:
            table = self.dynamodb.Table(self.config.session_table)
            table.put_item(Item={
                "session_id": session_id,
                "state": state,
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "ttl": int(datetime.now(timezone.utc).timestamp()) + 86400  # 24h TTL
            })
            logger.debug("session_state_saved", session_id=session_id)
            
        except ClientError as e:
            logger.warning(
                "session_save_failed",
                session_id=session_id,
                error=str(e)
            )
    
    def _get_help_text(self) -> str:
        """Return help text for the agent."""
        return """
I'm the Data Processor Agent. Here's what I can do:

**Data Analysis:**
- Say "analyze" with data loaded to get AI-powered insights

**Data Storage:**
- Say "store" with data in tool_inputs to save to DynamoDB

**Data Retrieval:**
- Say "retrieve" or "get" with an item_id or s3_key in tool_inputs

**List Items:**
- Say "list" or "show" to see recent items from your session

**Status:**
- Say "status" to see current session information

Include structured data in the `tool_inputs` field of your request.
"""
    
    def _get_status(self, session_state: dict[str, Any]) -> str:
        """Return current agent and session status."""
        turn_count = session_state.get("turn_count", 0)
        has_data = "current_data" in session_state
        last_analysis = session_state.get("last_analysis")
        
        return f"""
**Agent Status:**
- Name: {self.name}
- Version: {self.version}
- Region: {self.config.aws_region}

**Session Status:**
- Turn Count: {turn_count}
- Data Loaded: {'Yes' if has_data else 'No'}
- Last Analysis: {'Available' if last_analysis else 'None'}
"""
    
    def _error_response(
        self,
        message: str,
        error_type: str,
        session_id: str
    ) -> dict[str, Any]:
        """Generate a standardized error response."""
        return {
            "output_text": message,
            "session_id": session_id,
            "agent_name": self.name,
            "agent_version": self.version,
            "status": "error",
            "error_type": error_type,
            "tool_results": {},
            "metadata": {}
        }


# ==============================================================================
# Entry Point
# ==============================================================================

def main():
    """Main entry point for the agent container."""
    logger.info("agent_starting")
    
    agent = DataProcessorAgent()
    
    # Check if input is provided via stdin
    if not sys.stdin.isatty():
        try:
            event = json.load(sys.stdin)
            result = agent.handle(event)
            print(json.dumps(result, indent=2, default=str))
        except json.JSONDecodeError as e:
            logger.error("invalid_json_input", error=str(e))
            sys.exit(1)
    else:
        # Interactive mode for local development
        logger.info("interactive_mode", message="Running test invocation")
        test_event = {
            "input_text": "What can you help me with?",
            "session_id": "test-session-001",
            "agent_id": "data-processor"
        }
        result = agent.handle(test_event)
        print(json.dumps(result, indent=2, default=str))


if __name__ == "__main__":
    main()

