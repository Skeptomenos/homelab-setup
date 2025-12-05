# Pi-hole DNS & Ad-Blocking

Network-wide DNS server and ad-blocker. Blocks ads and trackers at the DNS level before they reach your devices.

## Access

| Type | URL |
|------|-----|
| Public | `https://pihole.yourdomain.com` |
| Local | `http://pihole.homelab.local` |

## Features

- Network-wide ad blocking
- Custom DNS entries
- DHCP server (optional)
- Query logging and statistics
- Protected by Authelia (public access)

## Directory Structure

```
pihole/
├── compose.yml
├── etc-pihole/       # Pi-hole config (persistent)
└── etc-dnsmasq.d/    # DNS config (persistent)
```

## Host Preparation (Fedora)

Port 53 is typically used by `systemd-resolved`. Free it before starting Pi-hole:

```bash
# Stop and disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Set fallback DNS
echo -e "nameserver 1.1.1.1\nnameserver 1.0.0.1" | sudo tee /etc/resolv.conf
```

## Configuration

### Environment Variables (in root `.env`)

```bash
SUBDOMAIN_PIHOLE=pihole
PIHOLE_WEBPASSWORD=your_admin_password
```

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 53 | TCP/UDP | DNS queries |

## Usage

### Start

```bash
docker compose --env-file ../.env up -d
```

### Reset Password

The `WEBPASSWORD` env var only works on first creation. To reset:

```bash
docker exec -it pihole pihole -a -p
```

### Configure Clients

Point your router or devices to use your server's IP as DNS server.

## Traefik Integration

Pi-hole is configured with:

1. **Redirect middleware** - `/` redirects to `/admin/`
2. **CSP headers** - Allows embedding in Home Assistant
3. **Authelia** - Required for public access

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Port 53 in use | Disable systemd-resolved (see above) |
| Can't resolve DNS | Check Pi-hole container is running |
| Password not working | Use `pihole -a -p` inside container |
| Local access not working | Verify DNS entry in router/hosts file |
