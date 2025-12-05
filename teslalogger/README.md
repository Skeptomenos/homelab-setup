# TeslaLogger

Multi-container stack for logging and visualizing Tesla vehicle data.

## Access

| Interface | URL | Purpose |
|-----------|-----|---------|
| Admin Panel | `https://teslalogger.yourdomain.com` | Configuration, settings |
| Grafana | `https://grafana.yourdomain.com` | Data visualization |

Both protected by Authelia.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   teslalogger   │────▶│    MariaDB      │
│   (core app)    │     │   (database)    │
└────────┬────────┘     └─────────────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐  ┌────────┐
│Grafana │  │Webserver│
│(charts)│  │ (admin) │
└────────┘  └─────────┘
```

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| `teslalogger` | bassmaster187/teslalogger | Core data collection |
| `teslalogger-database` | mariadb | Data storage |
| `teslalogger-grafana` | bassmaster187/teslalogger-grafana | Visualization |
| `teslalogger-webserver` | bassmaster187/teslalogger-webserver | Admin interface |

## Configuration

### Environment Variables (in root `.env`)

```bash
# Database
TESLALOGGER_DB_USER=teslalogger
TESLALOGGER_DB_PASSWORD=your_password
TESLALOGGER_DB_NAME=teslalogger
TESLALOGGER_DB_ROOT_PASSWORD=your_root_password

# Grafana
TESLALOGGER_GF_ADMIN_PASSWORD=your_grafana_password

# Domain
DOMAIN_PUBLIC=yourdomain.com
```

## Data Storage

| Type | Location | Contents |
|------|----------|----------|
| Named volumes | Docker-managed | Grafana dashboards, plugins, data |
| Host mount | `./mysql/` | MariaDB database files |
| Host mount | `./backup/` | Backup files |
| Host mount | `./invoices/` | Tesla invoices |

## Usage

### Start

```bash
docker compose --env-file ../.env up -d
```

### View Logs

```bash
docker compose logs -f teslalogger
docker compose logs -f teslalogger-grafana
```

### Initial Setup

1. Access admin panel at `https://teslalogger.yourdomain.com`
2. Configure Tesla account credentials
3. View data in Grafana at `https://grafana.yourdomain.com`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Database connection failed | Wait for MariaDB to initialize, check logs |
| Grafana not loading | Check Grafana container health |
| No Tesla data | Verify credentials in admin panel |
| Permission denied on volumes | Check `:Z` flag on host mounts |

## Reference

Based on [official TeslaLogger Docker setup](https://github.com/bassmaster187/TeslaLogger/blob/master/docker_setup.md).
