# Portainer Container Management

Web-based Docker management interface. Provides GUI for managing containers, images, volumes, and networks.

## Access

| Type | URL |
|------|-----|
| Public | `https://portainer.yourdomain.com` |

Protected by Authelia SSO, then Portainer's own login.

## Features

- Container management (start, stop, logs, shell)
- Image management (pull, remove)
- Volume and network management
- Stack deployment (compose files)
- Container resource monitoring

## Directory Structure

```
portainer/
├── compose.yml
└── data/          # Portainer config (persistent)
```

## Configuration

Portainer requires access to the Docker socket to manage containers:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  - ./data:/data:Z
```

## Usage

### Start

```bash
docker compose --env-file ../.env up -d
```

### Initial Setup

On first access:

1. Create admin account (choose strong password)
2. Select "Docker" environment
3. Connect to local Docker socket

### Commands

```bash
# View logs
docker compose logs -f

# Restart
docker compose restart

# Stop
docker compose down
```

## Security Notes

- Portainer has **full Docker access** via the socket mount
- Protected by both Authelia and Portainer's own authentication
- Use a strong, unique password for the Portainer admin account

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Can't connect to Docker | Verify socket mount in compose.yml |
| Permission denied | Check socket permissions on host |
| Lost admin password | Delete `data/` directory and reconfigure |
