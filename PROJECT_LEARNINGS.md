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

### 3.3. TeslaLogger Migration Constraints
- **Learning:** TeslaLogger uses hardcoded database credentials (`teslalogger`/`teslalogger` for both user and root). Custom credentials in `.env` are ignored by the TeslaLogger container—it always connects with the defaults.
- **Mandate:** Use default TeslaLogger DB credentials. Do not customize `TESLALOGGER_DB_PASSWORD` or `TESLALOGGER_DB_ROOT_PASSWORD`.
- **Outcome:** Reset database with default credentials for successful migration.

### 3.4. TeslaLogger Service Names Must Match Official docker-compose.yml
- **Learning:** TeslaLogger internally expects service names `database`, `grafana`, and `webserver`. Using custom names (e.g., `teslalogger-database`, `teslalogger-grafana`) causes connection failures and "Please update docker-compose.yml" warnings.
- **Mandate:** Always use official service names: `database`, `grafana`, `webserver`. Container names can be customized (e.g., `container_name: teslalogger-db`).
- **Outcome:** Renamed services to match official names; TeslaLogger now restarts Grafana correctly via Docker socket.

### 3.5. MariaDB 10.11+ Dump Compatibility with Older Versions
- **Learning:** MariaDB 10.11+ mysqldump adds `/*M!999999\- enable the sandbox mode */` as the first line. MariaDB 10.4.x does not understand this directive and fails with "Unknown command '\-'" error.
- **Mandate:** When restoring dumps from newer MariaDB to older versions, strip the first line: `tail -n +2 dumpfile.sql | mysql ...`
- **Outcome:** Successfully imported TeslaLogger backup from Raspberry Pi (MariaDB 10.11) to homelab (MariaDB 10.4.7).

### 3.6. TeslaLogger Requires Docker Socket for Grafana Restart
- **Learning:** TeslaLogger needs `/var/run/docker.sock` mounted to restart the Grafana container when updating dashboards. Without it, logs show "Can't access docker socket" errors.
- **Mandate:** Always include `- /var/run/docker.sock:/var/run/docker.sock` in TeslaLogger's volumes.
- **Outcome:** Added Docker socket mount; Grafana restart now works correctly.
