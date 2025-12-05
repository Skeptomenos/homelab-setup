# VS Code Server

Browser-based Visual Studio Code editor for remote development and configuration management.

## Access

| Type | URL |
|------|-----|
| Public | `https://code.yourdomain.com` |

Protected by Authelia SSO.

## Purpose

Provides a centralized environment for:

- Editing homelab configuration files
- Managing Docker compose files
- Git operations
- Terminal access to the server

## Directory Structure

```
vscode-server/
├── compose.yml
└── config/        # VS Code settings, extensions (persistent)
```

## Configuration

### Workspace Mount

The entire `/docker/` directory is mounted as the workspace:

```yaml
volumes:
  - ./config:/config:Z
  - /docker/:/config/workspace:Z
```

### User Permissions

Runs as user/group 1000 to match host permissions:

```yaml
environment:
  - PUID=${PUID}
  - PGID=${PGID}
```

### SELinux

The `:Z` flag is **mandatory** on Fedora for proper file access.

## Usage

### Start

```bash
docker compose --env-file ../.env up -d
```

### Access

1. Navigate to `https://code.yourdomain.com`
2. Authenticate via Authelia
3. Full VS Code IDE loads in browser

### Features Available

- File editing with syntax highlighting
- Integrated terminal
- Git integration
- Extension support
- Multi-file search

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Permission denied saving files | Check PUID/PGID match host user |
| Git operations fail | Verify user permissions on repository |
| Extensions not persisting | Check `./config` volume mount |
| SELinux blocking access | Ensure `:Z` flag on all volumes |

## Security Notes

- Full access to all homelab configuration files
- Protected by Authelia authentication
- Runs with `no-new-privileges:true`
