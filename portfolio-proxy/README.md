# Portfolio Prism API Proxy

API proxy for Portfolio Prism Docker distribution. Enables zero-config Docker distribution to friends while keeping API secrets secure.

## Purpose

Routes API calls from distributed Portfolio Prism containers through this proxy, keeping Finnhub and GitHub tokens on your server only.

## Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/health` | None | Health check |
| `GET` | `/api/finnhub/profile?symbol=AAPL` | X-API-Key | Proxy to Finnhub stock profile |
| `POST` | `/api/github/issues` | X-API-Key | Create GitHub issue for telemetry |

## Environment Variables

Add to root `.env`:

```bash
# Portfolio Proxy - Finnhub API key (https://finnhub.io/)
FINNHUB_API_KEY=your_finnhub_api_key

# Portfolio Proxy - GitHub fine-grained PAT with Issues (write) permission
GITHUB_ISSUES_TOKEN=your_github_pat

# Portfolio Proxy - Shared API key for client authentication
# Generate with: python -c "import secrets; print(secrets.token_urlsafe(32))"
PROXY_API_KEY=your_shared_secret

# Optional: Override defaults
SUBDOMAIN_PORTFOLIO_API=portfolio-api
GITHUB_OWNER=Skeptomenos
GITHUB_REPO=Portfolio-Prism
```

## Deployment

```bash
# Build and start
docker compose up -d --build

# Verify
curl https://portfolio-api.helmus.me/health

# Test Finnhub endpoint
curl -H "X-API-Key: YOUR_PROXY_API_KEY" \
     "https://portfolio-api.helmus.me/api/finnhub/profile?symbol=AAPL"
```

## Security

- No Authelia middleware - clients authenticate with `X-API-Key` header
- Secrets (Finnhub, GitHub tokens) never leave this server
- Shared `PROXY_API_KEY` can be rotated if compromised
- Rate limiting provided by Finnhub free tier (60 calls/min)

## Rotating API Key

1. Generate new key: `python -c "import secrets; print(secrets.token_urlsafe(32))"`
2. Update `.env` with new `PROXY_API_KEY`
3. Restart: `docker compose up -d`
4. Update client Docker image with new key
