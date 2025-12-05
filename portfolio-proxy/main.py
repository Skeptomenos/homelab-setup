"""
Portfolio Prism API Proxy

Securely proxies requests to Finnhub and GitHub APIs.
Validates requests using a shared API key.
"""

import os
from fastapi import FastAPI, HTTPException, Header, Query, Depends
from pydantic import BaseModel
import httpx

app = FastAPI(
    title="Portfolio Prism Proxy",
    description="API proxy for Portfolio Prism Docker distribution",
    version="1.0.0",
)

# Configuration from environment
FINNHUB_API_KEY = os.environ.get("FINNHUB_API_KEY")
GITHUB_ISSUES_TOKEN = os.environ.get("GITHUB_ISSUES_TOKEN")
PROXY_API_KEY = os.environ.get("PROXY_API_KEY")

# GitHub repo for telemetry
GITHUB_OWNER = os.environ.get("GITHUB_OWNER", "Skeptomenos")
GITHUB_REPO = os.environ.get("GITHUB_REPO", "Portfolio-Prism")


def verify_api_key(x_api_key: str = Header(..., alias="X-API-Key")):
    """Validate the shared API key."""
    if not PROXY_API_KEY:
        raise HTTPException(
            status_code=500, detail="Server misconfigured: PROXY_API_KEY not set"
        )
    if x_api_key != PROXY_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return x_api_key


@app.get("/health")
async def health():
    """Health check endpoint (no auth required)."""
    return {"status": "ok", "service": "portfolio-proxy"}


@app.get("/api/finnhub/profile")
async def finnhub_profile(
    symbol: str = Query(..., description="Stock symbol"),
    _api_key: str = Depends(verify_api_key),
):
    """
    Proxy to Finnhub stock profile endpoint.

    Returns company profile including ISIN, sector, and geography.
    """
    if not FINNHUB_API_KEY:
        raise HTTPException(
            status_code=500, detail="Server misconfigured: FINNHUB_API_KEY not set"
        )

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(
            "https://finnhub.io/api/v1/stock/profile2",
            params={"symbol": symbol},
            headers={"X-Finnhub-Token": FINNHUB_API_KEY},
        )

        if response.status_code != 200:
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Finnhub API error: {response.text}",
            )

        return response.json()


class GitHubIssueRequest(BaseModel):
    """Request body for creating a GitHub issue."""

    title: str
    body: str
    labels: list[str] = []


@app.post("/api/github/issues")
async def create_github_issue(
    request: GitHubIssueRequest,
    _api_key: str = Depends(verify_api_key),
):
    """
    Create a GitHub issue for error telemetry.

    Issues are created in the Portfolio-Prism repository.
    """
    if not GITHUB_ISSUES_TOKEN:
        raise HTTPException(
            status_code=500, detail="Server misconfigured: GITHUB_ISSUES_TOKEN not set"
        )

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/issues",
            json={
                "title": request.title,
                "body": request.body,
                "labels": request.labels,
            },
            headers={
                "Authorization": f"Bearer {GITHUB_ISSUES_TOKEN}",
                "Accept": "application/vnd.github.v3+json",
                "User-Agent": "Portfolio-Prism-Proxy",
            },
        )

        if response.status_code != 201:
            raise HTTPException(
                status_code=response.status_code,
                detail=f"GitHub API error: {response.text}",
            )

        return response.json()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8080)
