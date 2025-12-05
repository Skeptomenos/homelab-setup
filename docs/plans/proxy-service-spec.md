# Portfolio Prism API Proxy Service

> **Status:** Specification  
> **Created:** 2025-12-04  
> **Purpose:** Enable zero-config Docker distribution to friends while keeping API secrets secure

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Solution Overview](#solution-overview)
3. [Architecture](#architecture)
4. [Security Model](#security-model)
5. [Components](#components)
6. [Implementation Plan](#implementation-plan)
7. [Deployment Guide](#deployment-guide)
8. [Client Integration](#client-integration)
9. [Maintenance](#maintenance)

---

## Problem Statement

### The Goal

Distribute Portfolio Prism to friends with **zero configuration required**:

```bash
docker compose up -d
# Visit http://localhost:8501 - done!
```

### The Challenge

Portfolio Prism requires API keys for:

| Service | Purpose | Sensitivity |
|---------|---------|-------------|
| **Finnhub** | Stock/ETF metadata (ISIN, sector, geography) | Medium - free tier, but rate-limited |
| **GitHub Issues** | Automatic error telemetry | High - can create issues in your repo |

### Why Not Bake Secrets Into Docker Image?

Anyone who pulls a public Docker image can extract its environment variables:

```bash
docker inspect ghcr.io/skeptomenos/portfolio-prism:latest
# Shows all ENV variables including secrets
```

This exposes:
- Your Finnhub API key (could be abused for rate limit exhaustion)
- Your GitHub token (could create spam issues in your repo)

### Why Not Ask Friends to Create Their Own Keys?

1. **Friction** - Each friend needs to sign up for Finnhub, create GitHub PAT, configure env vars
2. **Telemetry breaks** - Friends won't have write access to YOUR GitHub repo for error reporting
3. **Support burden** - "It's not working" debugging becomes your problem

---

## Solution Overview

### The Proxy Approach

Instead of distributing secrets, route API calls through a proxy service you control:

```
┌─────────────────────────────────────────┐
│  Friend's Docker Container              │
│  - No secrets                           │
│  - Calls YOUR proxy                     │
└──────────────────┬──────────────────────┘
                   │ HTTPS
                   ▼
┌─────────────────────────────────────────┐
│  Your Proxy (portfolio-api.helmus.me)   │
│  - Validates shared API key             │
│  - Holds Finnhub + GitHub secrets       │
│  - Proxies requests                     │
└──────────────────┬──────────────────────┘
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
   Finnhub API          GitHub API
```

### Benefits

| Benefit | Description |
|---------|-------------|
| **Zero-config for friends** | Just `docker compose up` |
| **Secrets never leave your server** | Full control |
| **Revocable access** | Rotate `PROXY_API_KEY` anytime |
| **Centralized telemetry** | All errors go to YOUR repo |
| **Rate limit control** | Add throttling if needed |

---

## Architecture

### Full System Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  FRIEND'S MACHINE                                                           │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Docker Container: ghcr.io/skeptomenos/portfolio-prism:latest       │   │
│  │                                                                     │   │
│  │  Environment (baked into image):                                    │   │
│  │  ├─ PROXY_URL=https://portfolio-api.helmus.me                       │   │
│  │  └─ PROXY_API_KEY=<shared-secret>                                   │   │
│  │                                                                     │   │
│  │  NO FINNHUB_API_KEY                                                 │   │
│  │  NO GITHUB_ISSUES_TOKEN                                             │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 │                                           │
└─────────────────────────────────┼───────────────────────────────────────────┘
                                  │ HTTPS (TLS via Cloudflare/Traefik)
                                  │
                                  │ Headers:
                                  │ X-API-Key: <shared-secret>
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  CLOUDFLARE TUNNEL / TRAEFIK                                                │
│  https://portfolio-api.helmus.me                                            │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  YOUR HOME SERVER                                                           │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Docker Container: portfolio-proxy                                  │   │
│  │                                                                     │   │
│  │  Environment (secret, only on your server):                         │   │
│  │  ├─ FINNHUB_API_KEY=<your-actual-key>                               │   │
│  │  ├─ GITHUB_ISSUES_TOKEN=<your-actual-token>                         │   │
│  │  └─ PROXY_API_KEY=<shared-secret>  (for validation)                 │   │
│  │                                                                     │   │
│  │  Endpoints:                                                         │   │
│  │  ├─ GET  /health              → Returns {"status": "ok"}            │   │
│  │  ├─ GET  /api/finnhub/profile → Proxies to Finnhub                  │   │
│  │  └─ POST /api/github/issues   → Creates issue in your repo          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Request Flow Example

**Finnhub Profile Request:**

```
1. Friend's container calls:
   GET https://portfolio-api.helmus.me/api/finnhub/profile?symbol=AAPL
   Headers: X-API-Key: <shared-secret>

2. Proxy validates X-API-Key

3. Proxy calls Finnhub:
   GET https://finnhub.io/api/v1/stock/profile2?symbol=AAPL
   Headers: X-Finnhub-Token: <your-actual-finnhub-key>

4. Proxy returns Finnhub response to friend's container
```

**Telemetry (Error Reporting):**

```
1. Friend's container encounters error, calls:
   POST https://portfolio-api.helmus.me/api/github/issues
   Headers: X-API-Key: <shared-secret>
   Body: {"title": "Missing adapter for XYZ", "body": "...", "labels": ["bug"]}

2. Proxy validates X-API-Key

3. Proxy calls GitHub:
   POST https://api.github.com/repos/Skeptomenos/Portfolio-Prism/issues
   Headers: Authorization: Bearer <your-github-token>
   Body: {"title": "Missing adapter for XYZ", ...}

4. Issue created in YOUR repo, you get notified
```

---

## Security Model

### Secret Classification

| Secret | Location | Who Can Access |
|--------|----------|----------------|
| `FINNHUB_API_KEY` | Your home server only | Only you |
| `GITHUB_ISSUES_TOKEN` | Your home server only | Only you |
| `PROXY_API_KEY` | Baked into public Docker image | Anyone who pulls image |

### Risk Analysis for `PROXY_API_KEY`

The shared API key IS extractable from the Docker image. However:

| Risk | Mitigation |
|------|------------|
| Random internet user calls your proxy | They'd need to find the key first (requires pulling image, inspecting) |
| Abuse of Finnhub quota | Free tier = 60 calls/min. Worst case: they waste YOUR free quota |
| Spam GitHub issues | Rate limits in telemetry code (1 per ISIN per day) |
| DDoS your proxy | Cloudflare provides DDoS protection |

### If Compromised

1. Generate new `PROXY_API_KEY`
2. Update proxy server env var
3. Push new client Docker image with new key
4. Old key stops working immediately

**Recovery time: ~5 minutes**

### Enhanced Security (Optional)

If you want stronger protection:

| Option | How | Trade-off |
|--------|-----|-----------|
| Cloudflare Access | Zero-trust auth, friends auth via email | Friends need Cloudflare login |
| IP Allowlist | Only allow known friend IPs | IPs change, maintenance burden |
| Per-friend API keys | Issue unique key to each friend | More management |
| Rate limiting | Limit calls per minute in proxy | May break legitimate use |

---

## Components

### 1. Proxy Service

**Technology:** Python + FastAPI (lightweight, async, modern)

**Files:**

```
portfolio-proxy/
├── Dockerfile           # Alpine-based, ~50MB image
├── docker-compose.yml   # For deployment with Traefik
├── requirements.txt     # fastapi, uvicorn, httpx
├── main.py              # ~80 lines of proxy logic
└── .env.example         # Template for secrets
```

**Endpoints:**

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/health` | None | Health check for monitoring |
| `GET` | `/api/finnhub/profile` | Required | Proxy to Finnhub stock profile |
| `POST` | `/api/github/issues` | Required | Create GitHub issue |

### 2. Client Changes (Portfolio Prism)

**Files to modify:**

| File | Change |
|------|--------|
| `src/config.py` | Add `PROXY_URL`, `PROXY_API_KEY` config |
| `src/data/enrichment.py` | Route Finnhub calls through proxy when `PROXY_URL` set |
| `src/data/resolution.py` | Route Finnhub calls through proxy when `PROXY_URL` set |
| `src/utils/telemetry.py` | Route GitHub calls through proxy when `PROXY_URL` set |
| `Dockerfile` | Bake in `PROXY_URL` and `PROXY_API_KEY` |

**Logic pattern:**

```python
if PROXY_URL:
    # Distributed mode: call through proxy
    response = requests.get(
        f"{PROXY_URL}/api/finnhub/profile",
        params={"symbol": symbol},
        headers={"X-API-Key": PROXY_API_KEY},
    )
else:
    # Local dev mode: call directly
    response = requests.get(
        f"https://finnhub.io/api/v1/stock/profile2",
        params={"symbol": symbol},
        headers={"X-Finnhub-Token": FINNHUB_API_KEY},
    )
```

---

## Implementation Plan

### Phase 1: Create Proxy Service

**Estimated time:** 15 minutes

#### 1.1 Generate Secure API Key

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
# Example output: Kj8mN2pQ4rS6tU8vW0xY2zA4bC6dE8fG
```

Save this as `PROXY_API_KEY` - you'll need it in both proxy and client.

#### 1.2 Create Proxy Files

**`main.py`:**

```python
"""
Portfolio Prism API Proxy

Securely proxies requests to Finnhub and GitHub APIs.
Validates requests using a shared API key.
"""

import os
from fastapi import FastAPI, HTTPException, Header, Query
from pydantic import BaseModel
import httpx

app = FastAPI(
    title="Portfolio Prism Proxy",
    description="API proxy for Portfolio Prism Docker distribution",
    version="1.0.0",
)

# Configuration from environment
FINNHUB_API_KEY = os.environ["FINNHUB_API_KEY"]
GITHUB_ISSUES_TOKEN = os.environ["GITHUB_ISSUES_TOKEN"]
PROXY_API_KEY = os.environ["PROXY_API_KEY"]

# GitHub repo for telemetry
GITHUB_OWNER = "Skeptomenos"
GITHUB_REPO = "Portfolio-Prism"


def verify_api_key(x_api_key: str = Header(..., alias="X-API-Key")):
    """Validate the shared API key."""
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
    x_api_key: str = Header(..., alias="X-API-Key"),
):
    """
    Proxy to Finnhub stock profile endpoint.
    
    Returns company profile including ISIN, sector, and geography.
    """
    verify_api_key(x_api_key)
    
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
    x_api_key: str = Header(..., alias="X-API-Key"),
):
    """
    Create a GitHub issue for error telemetry.
    
    Issues are created in the Portfolio-Prism repository.
    """
    verify_api_key(x_api_key)
    
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
```

**`Dockerfile`:**

```dockerfile
FROM python:3.11-alpine

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY main.py .

# Non-root user for security
RUN adduser -D appuser
USER appuser

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

**`requirements.txt`:**

```
fastapi==0.109.0
uvicorn==0.27.0
httpx==0.26.0
pydantic==2.5.0
```

**`docker-compose.yml`:**

```yaml
version: "3.8"

services:
  portfolio-proxy:
    build: .
    container_name: portfolio-proxy
    environment:
      - FINNHUB_API_KEY=${FINNHUB_API_KEY}
      - GITHUB_ISSUES_TOKEN=${GITHUB_ISSUES_TOKEN}
      - PROXY_API_KEY=${PROXY_API_KEY}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portfolio-proxy.rule=Host(`portfolio-api.helmus.me`)"
      - "traefik.http.routers.portfolio-proxy.tls=true"
      - "traefik.http.routers.portfolio-proxy.tls.certresolver=letsencrypt"
      - "traefik.http.services.portfolio-proxy.loadbalancer.server.port=8080"
    networks:
      - traefik
    restart: unless-stopped

networks:
  traefik:
    external: true
```

**`.env.example`:**

```bash
# Finnhub API key (get from https://finnhub.io/)
FINNHUB_API_KEY=your_finnhub_api_key_here

# GitHub fine-grained PAT with Issues (write) permission
# Scope: Skeptomenos/Portfolio-Prism only
GITHUB_ISSUES_TOKEN=your_github_pat_here

# Shared API key for client authentication
# Generate with: python -c "import secrets; print(secrets.token_urlsafe(32))"
PROXY_API_KEY=your_generated_shared_secret_here
```

### Phase 2: Deploy Proxy

**Estimated time:** 10 minutes

```bash
# On your home server
cd /path/to/portfolio-proxy

# Create .env with real values
cp .env.example .env
nano .env  # Fill in actual secrets

# Build and start
docker compose up -d

# Verify
curl https://portfolio-api.helmus.me/health
# Should return: {"status":"ok","service":"portfolio-proxy"}
```

### Phase 3: Modify Portfolio Prism Client

**Estimated time:** 20 minutes

See [Client Integration](#client-integration) section for detailed code changes.

### Phase 4: Test End-to-End

**Estimated time:** 10 minutes

```bash
# Build new client image locally
docker build -t portfolio-prism:test .

# Run with proxy config
docker run -p 8501:8501 portfolio-prism:test

# Visit http://localhost:8501
# - Dashboard should load
# - Market data should work (via proxy)
# - Errors should create issues in your repo
```

### Phase 5: Push and Distribute

**Estimated time:** 5 minutes

```bash
git add .
git commit -m "feat: route API calls through proxy for Docker distribution"
git push origin main
# GitHub Actions builds and pushes to GHCR
```

---

## Deployment Guide

### Prerequisites

- Linux server with Docker installed
- Traefik running as reverse proxy
- Cloudflare tunnel or DNS pointing to your server
- Domain: `portfolio-api.helmus.me`

### Step-by-Step Deployment

```bash
# 1. Clone proxy repo to your server
git clone https://github.com/YOUR_USERNAME/portfolio-proxy.git
cd portfolio-proxy

# 2. Create .env file
cp .env.example .env

# 3. Edit .env with your actual secrets
nano .env

# 4. Verify Traefik network exists
docker network ls | grep traefik
# If not: docker network create traefik

# 5. Build and deploy
docker compose up -d --build

# 6. Check logs
docker compose logs -f

# 7. Test health endpoint
curl https://portfolio-api.helmus.me/health

# 8. Test Finnhub endpoint (with your API key)
curl -H "X-API-Key: YOUR_PROXY_API_KEY" \
     "https://portfolio-api.helmus.me/api/finnhub/profile?symbol=AAPL"
```

### Updating the Proxy

```bash
cd /path/to/portfolio-proxy
git pull
docker compose up -d --build
```

---

## Client Integration

### Files to Modify in Portfolio Prism

#### 1. `src/config.py`

Add proxy configuration:

```python
# Proxy configuration (for Docker distribution)
# When set, API calls route through the proxy instead of direct
PROXY_URL = os.getenv("PROXY_URL")  # e.g., https://portfolio-api.helmus.me
PROXY_API_KEY = os.getenv("PROXY_API_KEY")
```

#### 2. `src/data/enrichment.py`

Modify the Finnhub call (around line 290):

```python
from src.config import PROXY_URL, PROXY_API_KEY

# ... in enrich_securities_bulk function ...

if PROXY_URL and PROXY_API_KEY:
    # Distributed mode: route through proxy
    response = session.get(
        f"{PROXY_URL}/api/finnhub/profile",
        params={"symbol": identifier},
        headers={"X-API-Key": PROXY_API_KEY},
    )
else:
    # Local dev mode: direct call
    response = session.get(
        f"{FINNHUB_API_URL}/stock/profile2",
        params={"symbol": identifier},
    )
```

#### 3. `src/data/resolution.py`

Modify `_call_finnhub` method (around line 368):

```python
from src.config import PROXY_URL, PROXY_API_KEY

def _call_finnhub(self, ticker: str) -> Optional[str]:
    """Call Finnhub API for ISIN."""
    if not ticker:
        return None
    
    # Require either proxy or direct API key
    if not PROXY_URL and not FINNHUB_API_KEY:
        return None

    try:
        if PROXY_URL and PROXY_API_KEY:
            response = requests.get(
                f"{PROXY_URL}/api/finnhub/profile",
                params={"symbol": ticker},
                headers={"X-API-Key": PROXY_API_KEY},
                timeout=10,
            )
        else:
            response = requests.get(
                f"{FINNHUB_API_URL}/stock/profile2",
                params={"symbol": ticker},
                headers={"X-Finnhub-Token": FINNHUB_API_KEY},
                timeout=10,
            )
        
        # ... rest of function unchanged ...
```

#### 4. `src/utils/telemetry.py`

Modify `_create_issue` method (around line 208):

```python
from src.config import PROXY_URL, PROXY_API_KEY

def _create_issue(self, title: str, body: str, labels: list) -> dict:
    """Create a GitHub issue."""
    
    if PROXY_URL and PROXY_API_KEY:
        # Distributed mode: route through proxy
        url = f"{PROXY_URL}/api/github/issues"
        req = Request(url, method="POST")
        req.add_header("X-API-Key", PROXY_API_KEY)
        req.add_header("Content-Type", "application/json")
        
        data = {"title": title, "body": body, "labels": labels}
        req.data = json.dumps(data).encode()
    else:
        # Local dev mode: direct call
        url = f"{self._api_base}/issues"
        req = Request(url, method="POST")
        req.add_header("Authorization", f"Bearer {self.github_token}")
        req.add_header("Accept", "application/vnd.github.v3+json")
        req.add_header("Content-Type", "application/json")
        
        data = {"title": title, "body": body, "labels": labels}
        req.data = json.dumps(data).encode()
    
    req.add_header("User-Agent", "Portfolio-Prism")
    
    with urlopen(req, timeout=30) as response:
        return json.loads(response.read().decode())
```

#### 5. `Dockerfile`

Bake in proxy configuration:

```dockerfile
# ... existing content ...

# Environment (non-sensitive)
ENV DOCKER_MODE=true
ENV PYTHONUNBUFFERED=1

# Proxy configuration (for distributed Docker images)
ENV PROXY_URL=https://portfolio-api.helmus.me
ENV PROXY_API_KEY=YOUR_GENERATED_SHARED_SECRET_HERE

# ... rest of file ...
```

---

## Maintenance

### Monitoring

**Health check:**
```bash
curl https://portfolio-api.helmus.me/health
```

**Check logs:**
```bash
docker compose logs -f portfolio-proxy
```

### Rotating the Shared API Key

If you suspect the `PROXY_API_KEY` is compromised:

1. Generate new key:
   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   ```

2. Update proxy server:
   ```bash
   # Edit .env with new PROXY_API_KEY
   docker compose up -d
   ```

3. Update Portfolio Prism Dockerfile and push:
   ```bash
   # Update PROXY_API_KEY in Dockerfile
   git commit -am "security: rotate proxy API key"
   git push
   # New Docker image builds automatically
   ```

4. Old key stops working immediately

### Finnhub Rate Limits

Free tier: 60 calls/minute

If multiple friends use simultaneously and hit limits:
- Add rate limiting in proxy
- Upgrade to paid Finnhub tier
- Add caching in proxy (e.g., Redis with 1-hour TTL)

### Updating GitHub Token

If your `GITHUB_ISSUES_TOKEN` expires:

1. Create new fine-grained PAT at https://github.com/settings/tokens
2. Permissions: Issues (write) on Skeptomenos/Portfolio-Prism
3. Update `.env` on proxy server
4. Restart proxy: `docker compose up -d`

---

## Summary

| Component | Location | Contains Secrets |
|-----------|----------|------------------|
| Proxy service | Your home server | Yes (Finnhub, GitHub tokens) |
| Client Docker image | GHCR (public) | No (only proxy URL + shared key) |
| Shared API key | Both | Low sensitivity (only grants proxy access) |

**Friend experience:**
```bash
docker compose up -d
# That's it. Everything works.
```

**Your control:**
- All API calls flow through your server
- Full visibility via logs
- Revoke access by rotating shared key
- No secrets exposed in public Docker image
