#!/bin/bash
# SRE-Management-Skript (Version 3)
# - Lädt die globale .env-Datei aus dem Root-Verzeichnis.
# - Startet alle Services ODER nur die als Argumente übergebenen.
# - NEU: Ignoriert kritische Proxy-Dienste beim Starten von "allen".

# --- SRE-SCHUTZ: KRITISCHE INFRASTRUKTUR ---
# Diese Dienste werden beim Aufruf von "./start-all.sh" (ohne Argumente)
# übersprungen, um ein versehentliches Stoppen/Neustarten zu verhindern.
PROXY_SERVICES=("traefik" "authelia" "cloudflared")
# ---------------------------------------------

# Stoppt das Skript, wenn ein Befehl fehlschlägt
set -e

# Absoluten Pfad zum Skriptverzeichnis finden (robustere Methode)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"
echo "Working directory: $SCRIPT_DIR"

# Globale .env-Datei definieren
ENV_FILE="$SCRIPT_DIR/.env"

# Überprüfen, ob die globale .env-Datei existiert
if [ ! -f "$ENV_FILE" ]; then
    echo "FEHLER: Globale .env-Datei nicht gefunden unter: $ENV_FILE"
    echo "Skript wird abgebrochen."
    exit 1
else
    echo "Global .env file found. Proceeding..."
fi

# Fall 1: KEINE Argumente übergeben (Starte "alle" außer Proxys)
if [ "$#" -eq 0 ]; then
    echo "Starte alle nicht-kritischen Services..."
    
    # Iteriere über alle Unterverzeichnisse
    for SERVICE_DIR in */; do
        # Entferne den abschließenden Schrägstrich
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

        # Validierung (überspringe, wenn keine compose-Datei vorhanden ist)
        if [ -f "$SERVICE_DIR/compose.yml" ] || [ -f "$SERVICE_DIR/docker-compose.yml" ]; then
            echo "--- Bearbeite Service: $SERVICE_NAME ---"
            echo "Starte Services in: $SERVICE_DIR"
            
            # Führe den Befehl im Unterverzeichnis aus, aber lade die .env-Datei aus dem Root
            (cd "$SERVICE_DIR" && docker compose --env-file "$ENV_FILE" up -d --force-recreate)
            
            echo "-----------------------------------------------------"
        else
            echo "--- Überspringe Verzeichnis (keine Compose-Datei): $SERVICE_NAME ---"
        fi
    done
    echo "Alle nicht-kritischen Services wurden verarbeitet."

# Fall 2: Argumente übergeben (Starte nur diese)
else
    echo "Spezifische Services angefordert: $@"
    
    for SERVICE_NAME in "$@"; do
        SERVICE_DIR="./$SERVICE_NAME"
        
        # Validierung
        if [ ! -d "$SERVICE_DIR" ]; then
            echo "FEHLER: Verzeichnis $SERVICE_DIR für Service $SERVICE_NAME nicht gefunden."
            continue
        fi
        if [ ! -f "$SERVICE_DIR/compose.yml" ] && [ ! -f "$SERVICE_DIR/docker-compose.yml" ]; then
            echo "FEHLER: Keine Compose-Datei in $SERVICE_DIR gefunden."
            continue
        fi
        
        echo "--- Bearbeite Service: $SERVICE_NAME ---"
        echo "Starte Services in: $SERVICE_DIR"
        
        # Führe den Befehl im Unterverzeichnis aus
        (cd "$SERVICE_DIR" && docker compose --env-file "$ENV_FILE" up -d --force-recreate)
        
        echo "-----------------------------------------------------"
    done
    echo "Alle angeforderten Services wurden verarbeitet."
fi

