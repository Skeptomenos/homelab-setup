# Project Learnings & Constraints

This document tracks the specific constraints, patterns, and lessons learned *during the development of this project*.

**Rules for this file:**
1.  **Append Only:** Never delete existing learnings unless they are factually incorrect.
2.  **Telegraphic Style:** Be concise. (e.g., "SELinux requires :Z flag" > "I discovered that SELinux...").
3.  **Specifics:** Focus on *this* project (Docker quirks, Traefik/Authelia config, Fedora limits).

---

## 1. Project Constraints (Invariants)

*   All volume mounts MUST use `:Z` flag for SELinux compatibility on Fedora
*   Secrets stored in root `.env` file only—never commit credentials
*   Services exposed via Traefik require `proxy-netzwerk` external network
*   Public routes (*.helmus.me) require Authelia middleware
*   Proxy stack (Traefik/Authelia/Cloudflared) managed separately from other services

## 2. Patterns (The "How")

*   Each service gets its own directory with `compose.yml` and `README.md`
*   Dual-domain routing: public (`*.helmus.me` HTTPS) + local (`*.homelab.local` HTTP)
*   Health-check dependency chain: Authelia → Traefik → Cloudflared
*   Use `docker compose -f <dir>/compose.yml` pattern for per-service management
*   Internal networks named `*-intern` for service-to-service communication
*   Diun labels on containers for image update notifications

## 3. Anti-Patterns (What Failed)

*   Do not use `start-all.sh`/`stop-all.sh` for proxy stack—causes tunnel disruption
*   Do not expose ports directly on host for public services—use Traefik routing only
*   Do not hardcode secrets in compose files—always reference `.env` variables
