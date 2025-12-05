# Proxy Stack (Traefik + Authelia + Cloudflared)

The core security infrastructure for the homelab. All web traffic flows through this stack.

```
Internet ──▶ Cloudflare ──▶ cloudflared ──▶ Traefik ──▶ Authelia ──▶ Services
                            (tunnel)        (proxy)     (auth)
```

## Components

| Service | Port | Purpose |
|---------|------|---------|
| **Authelia** | 9091 | SSO portal with 2FA |
| **Traefik** | 80, 443 | Reverse proxy, TLS termination |
| **Cloudflared** | - | Secure tunnel to Cloudflare |

## Directory Structure

```
proxy/
├── compose.yml                 # All three services
├── authelia/
│   └── config/
│       ├── configuration.yml   # Auth rules, session config
│       ├── users.yaml          # User database
│       └── db.sqlite3          # Session storage (auto-created)
└── traefik/
    ├── traefik.yml             # Static configuration
    └── data/
        └── acme.json           # Let's Encrypt certificates
```

## Startup Sequence

The services start in a specific order using health checks:

```
1. Authelia starts → healthcheck passes
2. Traefik starts (depends_on: authelia healthy)
3. Cloudflared starts (depends_on: traefik healthy)
```

This prevents the "middleware not found" error that occurs when Traefik starts before Authelia.

## Configuration

### Traefik (`traefik/traefik.yml`)

| Setting | Value | Purpose |
|---------|-------|---------|
| `exposedByDefault` | `false` | Only containers with `traefik.enable=true` are exposed |
| `entryPoints.http` | `:80` | Redirects to HTTPS |
| `entryPoints.websecure` | `:443` | HTTPS with TLS |
| `dnsChallenge.provider` | `cloudflare` | Automatic Let's Encrypt via DNS |

### Authelia (`authelia/config/configuration.yml`)

| Setting | Purpose |
|---------|---------|
| `session.cookies` | Domain and cookie settings |
| `access_control.rules` | Which users can access which services |
| `authentication_backend.file` | Points to `users.yaml` |

## Usage

### Start the Stack

```bash
cd /docker/proxy
docker compose --env-file ../.env up -d
```

### Check Status

```bash
docker compose ps
# All containers should show "healthy"
```

### View Logs

```bash
docker compose logs -f
docker compose logs -f authelia  # Specific service
```

## Adding Users

Edit `authelia/config/users.yaml`:

```yaml
users:
  newuser:
    displayname: "New User"
    password: "$argon2id$..."  # Generate with: docker run authelia/authelia:latest authelia crypto hash generate argon2
    email: user@example.com
    groups:
      - admins
```

Restart Authelia: `docker compose restart authelia`

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| **502 Bad Gateway** | SELinux blocking network | `sudo setsebool -P container_connect_any on` |
| **middleware not found** | Traefik started before Authelia | Restart stack: `docker compose down && docker compose up -d` |
| **Authelia unhealthy** | Config error | Check logs: `docker logs authelia` |
| **acme.json permissions** | File too open | `chmod 600 traefik/data/acme.json` |
| **Can't issue cert for .local** | Let's Encrypt doesn't support local domains | Only use public domain in router rules |
| **Infinite loading after login** | Group mismatch | Ensure group in `users.yaml` matches `access_control.rules` |

## Environment Variables Required

```bash
# In root .env file
CLOUDFLARE_DNS_API_TOKEN=     # For Let's Encrypt DNS challenge
CLOUDFLARE_TUNNEL_TOKEN=      # For cloudflared tunnel
AUTHELIA_JWT_SECRET=          # Random 64+ char string
AUTHELIA_SESSION_SECRET=      # Random 64+ char string
AUTHELIA_STORAGE_ENCRYPTION_KEY=  # Random 64+ char string
DOMAIN_PUBLIC=yourdomain.com
SUBDOMAIN_AUTHELIA=auth
SUBDOMAIN_TRAEFIK=traefik
```

## Security Notes

- Proxy stack is **excluded** from `start-all.sh` / `stop-all.sh` to prevent accidental disruption
- Always manage this stack separately with explicit `docker compose` commands
- The `authelia@docker` middleware should be applied to all public routes
