# Homelab Setup

> **Root File:** Auto-loaded by AI CLI tools. Keep concise (<80 lines).

## Overview

Docker-based homelab infrastructure for self-hosting applications on Fedora with enterprise-grade security. Provides SSO via Authelia, reverse proxy via Traefik, and zero-trust internet access via Cloudflare Tunnel—all without exposing router ports.

## Tech Stack

- **Runtime:** Docker + Docker Compose
- **Proxy:** Traefik v3.5
- **Auth:** Authelia v4.39
- **OS:** Fedora (SELinux enabled)

## Structure

```
proxy/              # Core: Traefik, Authelia, Cloudflared
home-automation/    # Home Assistant, Zigbee2MQTT, Mosquitto, InfluxDB
n8n/                # Workflow automation + PostgreSQL
pihole/             # DNS/ad-blocking
portainer/          # Container management UI
teslalogger/        # Tesla data logging + MariaDB + Grafana
vscode-server/      # Browser-based IDE
diun/               # Image update notifications
coding/             # AI framework and templates
```

---

## Protocol

### Golden Rules

1. **State:** Read `.context/active_state.md` at start, update at end
2. **Specs:** Complex tasks (>1hr) require `docs/specs/`. No code without spec.
3. **Consensus:** Present plan, WAIT for approval before coding
4. **Epilogue:** MANDATORY after feature/design completion. Includes reflective thinking (T-RFL), not just documentation.

> **ESCAPE HATCH:** Simple questions or read-only tasks → skip protocol, act immediately.

### When to Read

| Task | File |
|------|------|
| New service, refactor | `coding/THINKING_DIRECTIVES.md` |
| Complex bug | `coding/THINKING_DIRECTIVES.md` (T1-RCA) |
| Implementation | `coding/EXECUTION_DIRECTIVES.md` |
| Config review | `coding/CODING_STANDARDS.md` |
| Project constraints | `PROJECT_LEARNINGS.md` |

---

## Commands

```bash
# Start all:  ./start-all.sh       Stop all:  ./stop-all.sh
# Start one:  docker compose -f <dir>/compose.yml up -d
# Logs:       docker compose -f <dir>/compose.yml logs -f
```

## Constraints

- All volume mounts MUST use `:Z` flag for SELinux compatibility
- Secrets go in root `.env` file (gitignored), never commit credentials
- Services exposed via Traefik need `proxy-netzwerk` external network
- Public routes require Authelia middleware; local routes are optional
- Proxy stack managed separately—`start-all.sh`/`stop-all.sh` skip it

## State Files

`.context/active_state.md` (current) | `.context/handover.md` (previous) | `docs/specs/tasks.md` (plan)
