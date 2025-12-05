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

### 3.1. Traefik Static Config Does NOT Support http.middlewares
- **Learning:** Adding `http:` block with `middlewares:` to `traefik.yml` (static config) silently breaks all routing—Traefik returns 404 for every request without any config error
- **Mandate:** NEVER add `http.middlewares` to `traefik.yml`. Define middlewares via Docker labels on containers or in dynamic config files only
- **Outcome:** Security headers and other middlewares must be defined in `compose.yml` labels (e.g., `traefik.http.middlewares.security-headers.headers.stsSeconds=31536000`)

### 3.2. Docker API Version Compatibility with Pinned Images
- **Learning:** Docker v29+ (Dec 2025) requires minimum API 1.44. Older images (e.g., Traefik v3.5.2 from Sept 2025) use API 1.24 and fail with "client version 1.24 is too old" error. This breaks silently—container starts but cannot communicate with Docker daemon.
- **Mandate:** When Docker daemon is updated, check that pinned images are compatible. Traefik and other Docker-socket-dependent services are especially vulnerable. Use recent image versions (within 2-3 months of Docker release).
- **Outcome:** Updated Traefik from v3.5.2 → v3.6.2. Consider using floating minor tags (e.g., `traefik:v3.6`) for auto-patch updates, or implement Diun alerts for critical infrastructure.
