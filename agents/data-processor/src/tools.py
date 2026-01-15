"""
Data Processor Agent - Tool Registry

This module defines the tools (capabilities) available to the agent.
Each tool encapsulates an AWS service interaction with proper error handling.
"""

import json
import uuid
from datetime import datetime, timezone
from typing import Any
from decimal import Decimal

import structlog
from botocore.exceptions import ClientError

logger = structlog.get_logger(__name__)


class DecimalEncoder(json.JSONEncoder):
    """JSON encoder that handles Decimal types from DynamoDB."""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super().default(obj)


class ToolRegistry:
    """
    Registry of tools available to the Data Processor Agent.
    
    Each method represents a tool that can be invoked during request processing.
    Tools are designed to be atomic, idempotent where possible, and well-logged.
    """
    
    def __init__(self, dynamodb, s3, bedrock):
        """
        Initialize the tool registry with AWS clients.
        
        Args:
            dynamodb: boto3 DynamoDB resource
            s3: boto3 S3 client
            bedrock: boto3 Bedrock Runtime client
        """
        self.dynamodb = dynamodb
        self.s3 = s3
        self.bedrock = bedrock
    
    # =========================================================================
    # DynamoDB Tools
    # =========================================================================
    
    def store_data(
        self,
        table_name: str,
        data: dict[str, Any],
        session_id: str
    ) -> dict[str, Any]:
        """
        Store data in DynamoDB.
        
        Args:
            table_name: Name of the DynamoDB table
            data: Data to store
            session_id: Session identifier for partitioning
        
        Returns:
            Result dict with item_id and status
        """
        item_id = str(uuid.uuid4())
        
        logger.info(
            "storing_data",
            table=table_name,
            item_id=item_id,
            session_id=session_id
        )
        
        table = self.dynamodb.Table(table_name)
        
        item = {
            "id": item_id,
            "session_id": session_id,
            "data": data,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "ttl": int(datetime.now(timezone.utc).timestamp()) + 604800  # 7 days
        }
        
        # Handle title if present
        if "title" in data:
            item["title"] = data["title"]
        
        table.put_item(Item=item)
        
        logger.info("data_stored", item_id=item_id)
        
        return {
            "status": "success",
            "item_id": item_id,
            "table": table_name
        }
    
    def get_data(
        self,
        table_name: str,
        item_id: str
    ) -> dict[str, Any]:
        """
        Retrieve data from DynamoDB.
        
        Args:
            table_name: Name of the DynamoDB table
            item_id: ID of the item to retrieve
        
        Returns:
            Result dict with data or not_found status
        """
        logger.info("retrieving_data", table=table_name, item_id=item_id)
        
        table = self.dynamodb.Table(table_name)
        
        response = table.get_item(Key={"id": item_id})
        
        if "Item" not in response:
            logger.info("data_not_found", item_id=item_id)
            return {
                "status": "not_found",
                "item_id": item_id
            }
        
        item = response["Item"]
        
        logger.info("data_retrieved", item_id=item_id)
        
        return {
            "status": "success",
            "item_id": item_id,
            "data": item.get("data", {}),
            "created_at": item.get("created_at"),
            "session_id": item.get("session_id")
        }
    
    def list_recent_items(
        self,
        table_name: str,
        session_id: str,
        limit: int = 10
    ) -> list[dict[str, Any]]:
        """
        List recent items for a session.
        
        Args:
            table_name: Name of the DynamoDB table
            session_id: Session identifier to filter by
            limit: Maximum number of items to return
        
        Returns:
            List of item summaries
        """
        logger.info(
            "listing_items",
            table=table_name,
            session_id=session_id,
            limit=limit
        )
        
        table = self.dynamodb.Table(table_name)
        
        # Note: This assumes a GSI on session_id exists
        # For production, you'd want to use Query instead of Scan
        response = table.scan(
            FilterExpression="session_id = :sid",
            ExpressionAttributeValues={":sid": session_id},
            Limit=limit
        )
        
        items = [
            {
                "id": item["id"],
                "title": item.get("title", "Untitled"),
                "created_at": item.get("created_at")
            }
            for item in response.get("Items", [])
        ]
        
        logger.info("items_listed", count=len(items))
        
        return items
    
    # =========================================================================
    # S3 Tools
    # =========================================================================
    
    def get_s3_object(
        self,
        bucket: str,
        key: str
    ) -> dict[str, Any]:
        """
        Retrieve an object from S3.
        
        Args:
            bucket: S3 bucket name
            key: Object key
        
        Returns:
            Result dict with content and metadata
        """
        logger.info("retrieving_s3_object", bucket=bucket, key=key)
        
        try:
            response = self.s3.get_object(Bucket=bucket, Key=key)
            
            content = response["Body"].read().decode("utf-8")
            
            # Try to parse as JSON
            try:
                content = json.loads(content)
            except json.JSONDecodeError:
                pass  # Keep as string if not JSON
            
            logger.info("s3_object_retrieved", bucket=bucket, key=key)
            
            return {
                "status": "success",
                "bucket": bucket,
                "key": key,
                "content": content,
                "content_type": response.get("ContentType"),
                "last_modified": str(response.get("LastModified"))
            }
            
        except ClientError as e:
            if e.response["Error"]["Code"] == "NoSuchKey":
                logger.info("s3_object_not_found", bucket=bucket, key=key)
                return {
                    "status": "not_found",
                    "bucket": bucket,
                    "key": key
                }
            raise
    
    def put_s3_object(
        self,
        bucket: str,
        key: str,
        content: Any,
        content_type: str = "application/json"
    ) -> dict[str, Any]:
        """
        Upload an object to S3.
        
        Args:
            bucket: S3 bucket name
            key: Object key
            content: Content to upload
            content_type: MIME type of the content
        
        Returns:
            Result dict with status and metadata
        """
        logger.info("uploading_s3_object", bucket=bucket, key=key)
        
        # Convert to JSON if dict/list
        if isinstance(content, (dict, list)):
            body = json.dumps(content, cls=DecimalEncoder)
            content_type = "application/json"
        else:
            body = str(content)
        
        self.s3.put_object(
            Bucket=bucket,
            Key=key,
            Body=body.encode("utf-8"),
            ContentType=content_type
        )
        
        logger.info("s3_object_uploaded", bucket=bucket, key=key)
        
        return {
            "status": "success",
            "bucket": bucket,
            "key": key
        }
    
    # =========================================================================
    # Bedrock Tools
    # =========================================================================
    
    def analyze_data(
        self,
        data: Any,
        prompt: str,
        model_id: str = "anthropic.claude-3-sonnet-20240229-v1:0"
    ) -> dict[str, Any]:
        """
        Use Bedrock to analyze data.
        
        Args:
            data: Data to analyze
            prompt: Analysis prompt from user
            model_id: Bedrock model identifier
        
        Returns:
            Analysis result with summary
        """
        logger.info("analyzing_data", model_id=model_id)
        
        # Prepare the data for the model
        data_str = json.dumps(data, cls=DecimalEncoder, indent=2)[:10000]  # Limit size
        
        analysis_prompt = f"""Analyze the following data and provide insights.

User Request: {prompt}

Data:
```json
{data_str}
```

Provide a concise analysis with key findings."""

        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1024,
            "messages": [
                {
                    "role": "user",
                    "content": analysis_prompt
                }
            ]
        }
        
        response = self.bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps(request_body)
        )
        
        response_body = json.loads(response["body"].read())
        analysis_text = response_body["content"][0]["text"]
        
        logger.info("analysis_complete")
        
        return {
            "status": "success",
            "summary": analysis_text,
            "model_id": model_id,
            "data_size": len(data_str)
        }

