# Homelab Setup

A secure, Docker-based homelab infrastructure running on Fedora with enterprise-grade security features.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        INTERNET                                     │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                   ┌────────▼────────┐
                   │   Cloudflare    │
                   │     Tunnel      │
                   └────────┬────────┘
                            │ (no open ports)
┌───────────────────────────▼─────────────────────────────────────────┐
│  YOUR SERVER                                                        │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐  │
│  │ cloudflared │───▶│   Traefik   │───▶│       Authelia          │  │
│  │   (tunnel)  │    │   (proxy)   │    │   (SSO + 2FA)           │  │
│  └─────────────┘    └──────┬──────┘    └─────────────────────────┘  │
│                            │                                        │
│         ┌──────────────────┼──────────────────┐                     │
│         ▼                  ▼                  ▼                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐              │
│  │Home Assistant│   │    n8n      │    │  Pi-hole    │   ...        │
│  │  Zigbee2MQTT│   │  Postgres   │    │             │              │
│  │  InfluxDB   │   │             │    │             │              │
│  └─────────────┘    └─────────────┘    └─────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

## Features

| Feature | Implementation |
|---------|----------------|
| **Zero-trust access** | Cloudflare Tunnel (no open router ports) |
| **Reverse proxy** | Traefik v3.5 with automatic Let's Encrypt TLS |
| **Single Sign-On** | Authelia with 2FA support |
| **SELinux compatible** | All mounts use `:Z` flag for Fedora |
| **Centralized config** | Single `.env` file for all secrets |
| **Container monitoring** | Diun for image update notifications |

## Services

| Service | Purpose | Subdomain |
|---------|---------|-----------|
| **Traefik** | Reverse proxy & TLS | `traefik.` |
| **Authelia** | SSO authentication | `auth.` |
| **Home Assistant** | Smart home control | `home.` |
| **Zigbee2MQTT** | Zigbee device bridge | `zigbee.` |
| **n8n** | Workflow automation | `n8n.` |
| **Pi-hole** | DNS & ad-blocking | `pihole.` |
| **Portainer** | Container management | `portainer.` |
| **TeslaLogger** | Vehicle data logging | `teslalogger.` |
| **VS Code Server** | Browser-based IDE | `code.` |
| **Portfolio Proxy** | API proxy service | `portfolio-api.` |

## Quick Start

### Prerequisites

- Fedora-based server with Docker & Docker Compose v2
- Cloudflare account with configured domain
- Cloudflare Tunnel token

### Installation

```bash
# 1. Clone repository
git clone <your-repo-url> /docker
cd /docker

# 2. Create environment file
cp .env.example .env
nano .env  # Fill in your values

# 3. Create shared network
docker network create proxy-netzwerk

# 4. Set permissions
sudo chown -R 1000:1000 .
chmod +x start-all.sh stop-all.sh

# 5. Start proxy stack first
docker compose -f proxy/compose.yml up -d

# 6. Start all other services
./start-all.sh
```

## Architecture

### Request Flow

```
Internet Request (https://app.yourdomain.com)
    │
    ▼
┌─────────────────┐
│ Cloudflare CDN  │  DDoS protection, DNS
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   cloudflared   │  Secure tunnel (no open ports)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Traefik      │  TLS termination, routing
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Authelia     │  Authentication check
└────────┬────────┘
         │ (authenticated)
         ▼
┌─────────────────┐
│  Target Service │  Your application
└─────────────────┘
```

### Network Isolation

| Network | Purpose | Services |
|---------|---------|----------|
| `proxy-netzwerk` | External access via Traefik | All public services |
| `ha-intern` | Home automation internal | HA, Zigbee2MQTT, MQTT, InfluxDB |

## Project Structure

```
/docker/
├── .env                    # Global secrets (gitignored)
├── .gitignore
├── start-all.sh            # Start all services (except proxy)
├── stop-all.sh             # Stop all services (except proxy)
│
├── proxy/                  # Core infrastructure (manage separately)
│   ├── compose.yml
│   ├── authelia/
│   │   └── config/
│   └── traefik/
│
├── home-automation/        # Smart home stack
│   ├── compose.yml
│   └── mosquitto/
│
├── n8n/                    # Workflow automation
│   └── compose.yml
│
├── pihole/                 # DNS & ad-blocking
│   └── compose.yml
│
├── portainer/              # Container management
│   └── compose.yml
│
├── teslalogger/            # Tesla data logging
│   └── compose.yml
│
├── vscode-server/          # Browser IDE
│   └── compose.yml
│
├── diun/                   # Image update notifications
│   ├── compose.yml
│   └── diun.yml
│
├── portfolio-proxy/        # API proxy service
│   ├── compose.yml
│   ├── Dockerfile
│   └── main.py
│
└── docs/                   # Documentation & specs
    └── plans/
```

## Daily Management

### Scripts

The management scripts protect critical infrastructure by skipping the `proxy/` directory:

```bash
# Start all services (except proxy stack)
./start-all.sh

# Stop all services (except proxy stack)
./stop-all.sh

# Start specific service(s)
./start-all.sh n8n pihole

# Manage proxy stack separately
docker compose -f proxy/compose.yml up -d
docker compose -f proxy/compose.yml down
```

### Common Commands

```bash
# View logs
docker compose -f <service>/compose.yml logs -f

# Restart single service
docker compose -f <service>/compose.yml restart

# Update service image
docker compose -f <service>/compose.yml pull
docker compose -f <service>/compose.yml up -d

# Check all container status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## Adding a New Service

1. **Create service directory:**
   ```bash
   mkdir my-service
   ```

2. **Create compose.yml:**
   ```yaml
   services:
     my-service:
       image: some/image:version
       container_name: my-service
       restart: unless-stopped
       security_opt:
         - no-new-privileges:true
       environment:
         - PUID=${PUID}
         - PGID=${PGID}
         - TZ=${TZ}
       volumes:
         - ./config:/config:Z
       networks:
         - proxy-netzwerk
       labels:
         - "diun.enable=true"
         - "traefik.enable=true"
         - "traefik.http.routers.my-service.rule=Host(`${SUBDOMAIN_MYSERVICE}.${DOMAIN_PUBLIC}`)"
         - "traefik.http.routers.my-service.entrypoints=websecure"
         - "traefik.http.routers.my-service.tls=true"
         - "traefik.http.routers.my-service.tls.certresolver=letsencrypt"
         - "traefik.http.routers.my-service.middlewares=authelia@docker"
         - "traefik.http.services.my-service.loadbalancer.server.port=8080"

   networks:
     proxy-netzwerk:
       external: true
   ```

3. **Add to `.env`:**
   ```bash
   SUBDOMAIN_MYSERVICE=myapp
   ```

4. **Add Authelia rule** (if needed) in `proxy/authelia/config/configuration.yml`

5. **Start:**
   ```bash
   ./start-all.sh my-service
   ```

## Environment Variables

Required variables in `.env`:

```bash
# User/Group IDs
PUID=1000
PGID=1000
TZ=Europe/Berlin

# Domains
DOMAIN_LOCAL=homelab.local
DOMAIN_PUBLIC=yourdomain.com

# Subdomains
SUBDOMAIN_AUTHELIA=auth
SUBDOMAIN_TRAEFIK=traefik
SUBDOMAIN_HOMEASSISTANT=home
# ... add more as needed

# Secrets (generate with: openssl rand -base64 32)
AUTHELIA_JWT_SECRET=
AUTHELIA_SESSION_SECRET=
AUTHELIA_STORAGE_ENCRYPTION_KEY=
CLOUDFLARE_TUNNEL_TOKEN=
CLOUDFLARE_DNS_API_TOKEN=
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Permission Denied** | Run `sudo chown -R 1000:1000 .` and ensure volumes have `:Z` flag |
| **404 Not Found** | Check Traefik labels for typos, clear browser cache |
| **502 Bad Gateway** | Verify service is running, on `proxy-netzwerk`, and port label is correct |
| **Port 53 in use** | Disable systemd-resolved: `sudo systemctl disable --now systemd-resolved` |
| **SELinux denials** | Check all volume mounts have `:Z` suffix |
| **Container won't start** | Check logs: `docker compose -f <service>/compose.yml logs` |

## Security Notes

- All public routes require Authelia authentication (except explicitly bypassed)
- Secrets stored only in `.env` file (gitignored)
- All containers run with `no-new-privileges:true`
- SELinux enforced with proper context labels
- No ports exposed directly to internet (Cloudflare Tunnel)

## License

Private homelab configuration - not for redistribution.
