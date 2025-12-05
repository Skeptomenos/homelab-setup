# Handover Summary

**Last Updated:** 2025-12-05  
**Session Focus:** Fix Traefik routing failure (two separate issues)

---

## Where Are We?

- **Issue 1 Fixed:** Removed invalid `http.middlewares` block from `proxy/traefik/traefik.yml` (static config doesn't support this)
- **Issue 2 Fixed:** Updated Traefik from v3.5.2 → v3.6.2 to resolve Docker API 1.44+ compatibility
- **Root Cause:** Docker v29.1.2 (Dec 2025) dropped support for API <1.44; Traefik v3.5.2 (Sept 2025) used API 1.24

## What's Next?

1. **Deploy on server:**
   ```bash
   git pull
   docker compose -f proxy/compose.yml pull traefik
   docker compose -f proxy/compose.yml up -d
   ```
2. **Verify:** Check `docker logs traefik` - no more API version errors
3. **Rotate Cloudflare token:** `CF_DNS_API_TOKEN` was exposed in debug output
4. **Configure Pi-hole:** Add `*.homelab.local` → `192.168.178.2`

## Key Learnings (Added to PROJECT_LEARNINGS.md)

1. **Traefik static config:** Does NOT support `http.middlewares` - use Docker labels
2. **Docker API compatibility:** Pinned images can break when Docker daemon is updated; keep images within 2-3 months of Docker version

## Commits This Session

- `7b9284c` - Fix Traefik 404: remove invalid http.middlewares from static config
- `9e8bf6e` - Update Traefik to v3.6.2 for Docker API 1.44+ compatibility
