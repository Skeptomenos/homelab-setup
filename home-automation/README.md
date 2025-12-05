# Home Automation Stack

Complete smart home stack with Home Assistant, Zigbee support, MQTT messaging, and time-series data storage.

## Access

| Service | URL | Auth |
|---------|-----|------|
| Home Assistant | `https://home.yourdomain.com` | Built-in (no Authelia) |
| Zigbee2MQTT | `https://zigbee.yourdomain.com` | Authelia |

## Architecture

```
                                    ┌─────────────────┐
                                    │  Zigbee Devices │
                                    │  (sensors, etc) │
                                    └────────┬────────┘
                                             │ Zigbee
                                    ┌────────▼────────┐
┌─────────────┐                     │   Zigbee2MQTT   │
│  InfluxDB   │◀────────────────────│   (bridge)      │
│  (metrics)  │                     └────────┬────────┘
└──────▲──────┘                              │ MQTT
       │                            ┌────────▼────────┐
       │                            │    Mosquitto    │
       │                            │  (MQTT broker)  │
       │                            └────────┬────────┘
       │                                     │ MQTT
       │         ┌───────────────────────────┘
       │         │
┌──────┴─────────▼────┐
│    Home Assistant   │
│   (control center)  │
└─────────────────────┘
```

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| **Home Assistant** | `homeassistant/home-assistant:2025.12.0` | Central smart home control |
| **Zigbee2MQTT** | `ghcr.io/koenkk/zigbee2mqtt:2.7.0` | Zigbee device bridge |
| **Mosquitto** | `eclipse-mosquitto:2` | MQTT message broker |
| **InfluxDB** | `influxdb:2.7` | Time-series database for metrics |

## Directory Structure

```
home-automation/
├── compose.yml
├── homeassistant/
│   ├── config/           # Home Assistant configuration
│   └── influxdb/
│       └── influxdb2/    # InfluxDB data
├── mosquitto/
│   ├── config/
│   │   └── mosquitto.conf
│   ├── data/             # Persistent MQTT data
│   └── log/              # MQTT logs
└── zigbee2mqtt/
    └── z2m-data/         # Zigbee2MQTT configuration
```

## Networks

| Network | Purpose | Services |
|---------|---------|----------|
| `ha-intern` | Internal communication | All services |
| `proxy-netzwerk` | Traefik routing | Home Assistant, Zigbee2MQTT |

InfluxDB and Mosquitto are **not** exposed to proxy-netzwerk - they're internal only.

## Configuration

### Environment Variables (in root `.env`)

```bash
# Timezone
TZ=Europe/Berlin

# Zigbee coordinator device path
ZIGBEE_DEVICE_PATH=/dev/ttyUSB0

# InfluxDB
INFLUXDB_ADMIN_USER=admin
INFLUXDB_ADMIN_PASSWORD=your_password
INFLUXDB_ORG=homelab
INFLUXDB_BUCKET=homeassistant
INFLUXDB_ADMIN_TOKEN=your_token
INFLUXDB_RETENTION_DURATION=30d

# Subdomains
SUBDOMAIN_HOMEASSISTANT=home
SUBDOMAIN_ZIGBEE2MQTT=zigbee
```

### Mosquitto Configuration

Located at `mosquitto/config/mosquitto.conf`:

```conf
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
```

Anonymous access is enabled because Mosquitto is only accessible on the internal `ha-intern` network.

## Usage

### Start

```bash
docker compose --env-file ../.env up -d
```

### View Logs

```bash
docker compose logs -f homeassistant
docker compose logs -f zigbee2mqtt
docker compose logs -f mosquitto
docker compose logs -f influxdb
```

### Initial Setup

1. **Home Assistant**: Access `https://home.yourdomain.com` and complete onboarding
2. **Zigbee2MQTT**: Devices are automatically discovered when paired
3. **InfluxDB**: Configure in Home Assistant's `configuration.yaml`:

```yaml
influxdb:
  api_version: 2
  host: influxdb
  port: 8086
  token: !secret influxdb_token
  organization: homelab
  bucket: homeassistant
```

## Zigbee Device Pairing

1. Access Zigbee2MQTT UI at `https://zigbee.yourdomain.com`
2. Enable pairing mode (Permit Join)
3. Put device in pairing mode (usually hold button for 5+ seconds)
4. Device appears in Zigbee2MQTT, then in Home Assistant

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Zigbee2MQTT can't find coordinator | Check `ZIGBEE_DEVICE_PATH` matches actual device |
| MQTT connection refused | Verify Mosquitto is running: `docker compose ps` |
| InfluxDB not receiving data | Check Home Assistant logs for connection errors |
| Permission denied on volumes | Ensure all mounts have `:Z` flag for SELinux |
| Zigbee devices not pairing | Check coordinator firmware, try closer to device |

## Security Notes

- Home Assistant uses its own authentication (no Authelia) - it has robust built-in auth
- Zigbee2MQTT is protected by Authelia
- InfluxDB and Mosquitto are internal-only (not exposed via Traefik)
- Home Assistant port bound to localhost (`127.0.0.1:8123`) - public access via Traefik only
