#!/bin/bash
# SRE-Management-Skript (Version 4)
# - Lädt die globale .env-Datei aus dem Root-Verzeichnis.
# - Stoppt alle Services ODER nur die als Argumente übergebenen.
# - Ignoriert kritische Proxy-Dienste beim Stoppen von "allen".

# --- SRE-SCHUTZ: KRITISCHE INFRASTRUKTUR ---
# SRE-FIX: Das Array enthält jetzt den Verzeichnisnamen "proxy".
PROXY_SERVICES=("proxy" "traefik" "authelia" "cloudflared")
# ---------------------------------------------

set -e
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"
echo "Working directory: $SCRIPT_DIR"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "FEHLER: Globale .env-Datei nicht gefunden unter: $ENV_FILE"
    exit 1
else
    echo "Global .env file found. Proceeding..."
fi

# Fall 1: KEINE Argumente übergeben (Stoppe "alle" außer Proxys)
if [ "$#" -eq 0 ]; then
    echo "Stoppe alle nicht-kritischen Services..."
    
    for SERVICE_DIR in */; do
        SERVICE_NAME=$(basename "$SERVICE_DIR")
        
        # --- PROXY-SCHUTZ-LOGIK ---
        SKIP=false
        for PROXY_SERVICE in "${PROXY_SERVICES[@]}"; do
            if [ "$SERVICE_NAME" == "$PROXY_SERVICE" ]; then
                SKIP=true
                break
            fi
        done

        if [ "$SKIP" = true ]; then
            echo "--- Überspringe kritische Infrastruktur: $SERVICE_NAME ---"
            continue
        fi
        # --- ENDE PROXY-SCHUTZ ---

        if [ -f "$SERVICE_DIR/compose.yml" ] || [ -f "$SERVICE_DIR/docker-compose.yml" ]; then
            echo "--- Bearbeite Service: $SERVICE_NAME ---"
            echo "Stoppe Services in: $SERVICE_DIR"
            (cd "$SERVICE_DIR" && docker compose --env-file "$ENV_FILE" down)
            echo "-----------------------------------------------------"
        else
            echo "--- Überspringe Verzeichnis (keine Compose-Datei): $SERVICE_NAME ---"
        fi
    done
    echo "Alle nicht-kritischen Services wurden heruntergefahren."

# Fall 2: Argumente übergeben (Stoppe nur diese)
else
    echo "Spezifische Services zum Stoppen angefordert: $@"
    
    for SERVICE_NAME in "$@"; do
        SERVICE_DIR="./$SERVICE_NAME"
        
        if [ ! -d "$SERVICE_DIR" ]; then
            echo "FEHLER: Verzeichnis $SERVICE_DIR für Service $SERVICE_NAME nicht gefunden."
            continue
        fi
        if [ ! -f "$SERVICE_DIR/compose.yml" ] && [ ! -f "$SERVICE_DIR/docker-compose.yml" ]; then
            echo "FEHLER: Keine Compose-Datei in $SERVICE_DIR gefunden."
            continue
        fi
        
        echo "--- Bearbeite Service: $SERVICE_NAME ---"
        echo "Stoppe Services in: $SERVICE_DIR"
        (cd "$SERVICE_DIR" && docker compose --env-file "$ENV_FILE" down)
        echo "-----------------------------------------------------"
    done
    echo "Alle angeforderten Services wurden heruntergefahren."
fi

