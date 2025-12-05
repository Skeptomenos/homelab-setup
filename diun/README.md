# Diun (Docker Image Update Notifier)

Monitors Docker images for updates and sends webhook notifications to n8n.

## How It Works

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    Diun     │────▶│     n8n     │────▶│   Update    │
│  (monitor)  │     │  (workflow) │     │  Decision   │
└─────────────┘     └─────────────┘     └─────────────┘
      │
      ▼
┌─────────────┐
│   Docker    │
│   Socket    │
│  (read-only)│
└─────────────┘
```

Diun checks registries daily at 3:00 AM and sends webhooks when updates are found.

## Configuration Files

| File | Purpose |
|------|---------|
| `compose.yml` | Container configuration, volumes, network |
| `diun.yml` | Watch schedule, notification settings |

## Security Policy: Default-Deny

**By default, Diun monitors ZERO containers.**

This is intentional (`watchByDefault: false`) to protect critical infrastructure (Traefik, Authelia, Cloudflared) from automated updates.

### Enabling Monitoring

Add the `diun.enable=true` label to any service you want monitored:

```yaml
services:
  my-service:
    image: some/image:latest
    labels:
      - "diun.enable=true"  # Opt-in to monitoring
```

Then restart the service:

```bash
./start-all.sh my-service
```

## Configuration Details

### compose.yml

| Setting | Purpose |
|---------|---------|
| `command: serve` | Required when using config file |
| Docker socket mount | Read-only access to see running containers |
| `./data:/data:Z` | Persistent storage for image manifests |
| `./diun.yml:/diun.yml:ro,Z` | Application configuration |
| `proxy-netzwerk` | Required to reach n8n for webhooks |

### diun.yml

| Setting | Value | Purpose |
|---------|-------|---------|
| `schedule` | `0 3 * * *` | Check at 3:00 AM daily |
| `watchByDefault` | `false` | Only monitor labeled containers |
| `webhook.endpoint` | `http://n8n:5678/...` | Internal n8n webhook URL |

## Usage

### Start

```bash
docker compose --env-file ../.env up -d
```

### Check Status

```bash
docker compose logs -f diun
```

### Force Check

```bash
docker compose exec diun diun check
```

## Troubleshooting

| Log Message | Meaning | Action |
|-------------|---------|--------|
| `WRN No image found` | Normal - no containers have `diun.enable=true` | Add label to services you want monitored |
| `FTL Cannot load configuration` | Config file error | Check `diun.yml` syntax |
| Webhook not received in n8n | Network or workflow issue | Verify both on `proxy-netzwerk`, check workflow is active |

## Environment Variables

```bash
# In root .env
TZ=Europe/Berlin      # Timezone for schedule
PUID=1000             # User ID for file permissions
PGID=1000             # Group ID for file permissions
```
