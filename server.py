#!/usr/bin/env python3
"""Minimal MCP Server for Requirements API."""
import os
import httpx
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field

mcp = FastMCP("requirements")

# Config from env vars
API_BASE_URL = os.getenv("REQUIREMENTS_API_ENDPOINT", "http://localhost:3000")
API_TOKEN = os.getenv("REQUIREMENTS_API_TOKEN")

# Static request body fields (only 'pbi' changes)
STATIC_BODY = {
    "field1": "value1",
    "field2": "value2",
}


class ListReqsInput(BaseModel):
    name: str = Field(..., description="Filter by name")
    pbi: str = Field(..., description="Filter by PBI (project ID)")


async def call_api(name: str, pbi: str) -> dict:
    """Call requirements API with URL params and JSON body."""
    url = f"{API_BASE_URL}/dt"
    params = {"role": "true", "name": name, "pbi": pbi}
    body = {**STATIC_BODY, "pbi": pbi}

    headers = {"Authorization": f"Bearer {API_TOKEN}"} if API_TOKEN else {}

    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(url, headers=headers, params=params, json=body)
        resp.raise_for_status()
        return resp.json()


@mcp.tool()
async def list_requirements(params: ListReqsInput) -> str:
    """Get list of requirements by name and PBI."""
    try:
        data = await call_api(params.name, params.pbi)
        # Return raw JSON response
        return str(data)
    except Exception as e:
        return f"Error: {e}"


if __name__ == "__main__":
    mcp.run()
