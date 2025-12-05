# n8n Workflow Automation

Workflow automation platform with PostgreSQL backend. Uses native authentication (not Authelia SSO).

## Access

| Type | URL |
|------|-----|
| Public | `https://n8n.yourdomain.com` |

## Architecture

```
┌─────────────┐     ┌─────────────┐
│  PostgreSQL │◀────│     n8n     │
│   (data)    │     │  (workflows)│
└─────────────┘     └─────────────┘
                           │
                    ┌──────▼──────┐
                    │   Traefik   │
                    └─────────────┘
```

## Why Not Authelia SSO?

n8n Community Edition doesn't natively support header-based SSO. Previous attempts with `hooks.js` workarounds proved:

- **Fragile** - Broke with every n8n update
- **High maintenance** - Required reverse-engineering internal APIs
- **Unreliable** - Timing issues with internal objects

**Decision:** Use n8n's built-in authentication for stability.

## Configuration

### Environment Variables (in root `.env`)

```bash
# PostgreSQL
POSTGRES_USER=n8n
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=n8n

# n8n Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_secure_password
N8N_ENCRYPTION_KEY=random_64_char_string
N8N_JWT_SECRET=random_64_char_string
```

### Traefik Labels

No Authelia middleware - n8n handles its own auth:

```yaml
labels:
  - "traefik.http.routers.n8n-main.rule=Host(`n8n.${DOMAIN_PUBLIC}`)"
  - "traefik.http.routers.n8n-main.middlewares=iframe-headers@docker"
```

## Home Assistant Integration

n8n can be embedded in Home Assistant dashboards. The `iframe-headers` middleware sets the required CSP header:

```yaml
- "traefik.http.middlewares.iframe-headers.headers.contentSecurityPolicy=frame-ancestors 'self' https://home.${DOMAIN_PUBLIC}"
```

## Usage

### Start

```bash
docker compose --env-file ../.env up -d
```

### Access

1. Navigate to `https://n8n.yourdomain.com`
2. Login with `N8N_BASIC_AUTH_USER` and `N8N_BASIC_AUTH_PASSWORD`

### View Logs

```bash
docker compose logs -f n8n
docker compose logs -f postgres
```

## Diun Integration

This service is monitored for image updates. When Diun detects a new version, it sends a webhook to the n8n workflow for changelog review.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Database connection failed | Check PostgreSQL is healthy: `docker compose ps` |
| Login not working | Verify `N8N_BASIC_AUTH_*` variables in `.env` |
| Workflows not persisting | Check PostgreSQL volume permissions |
