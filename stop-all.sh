#!/bin/bash

# SRE Homelab - Master Stop Script
# Dieses Skript stellt sicher, dass die globale .env-Datei (Single Source of Truth)
# *immer* korrekt geladen wird, um Services sauber herunterzufahren.
#
# USAGE:
#   ./stop-all.sh               (Stoppt ALLE Services in allen Unterverzeichnissen)
#   ./stop-all.sh diun          (Stoppt NUR den Service im Verzeichnis ./diun)
#   ./stop-all.sh diun n8n ...  (Stoppt alle angegebenen Services nacheinander)

# --- Pruefungen ---
# Stelle sicher, dass wir uns im Verzeichnis des Skripts befinden (z.B. /docker)
cd "$(dirname "$0")"
echo "Working directory: $(pwd)"

# Finde die globale .env-Datei (Single Source of Truth)
ENV_FILE_PATH="./.env"

if [ ! -f "$ENV_FILE_PATH" ]; then
    echo "-----------------------------------------------------"
    echo "!! SRE CRITICAL ERROR !!"
    echo "Globale .env-Datei nicht gefunden unter: $ENV_FILE_PATH"
    echo "Kann Status der Services nicht verwalten."
    echo "-----------------------------------------------------"
    exit 1
fi

echo "Global .env file found. Proceeding..."
echo " "

# --- Argumenten-Handling ---

if [ $# -eq 0 ]; then
    # --- FALL 1: KEINE ARGUMENTE ---
    # Stoppe alle Services (bisheriges Verhalten)
    
    echo "Kein spezifischer Service angefordert. Stoppe ALLE Services..."

    find . -mindepth 2 -name 'compose.yml' | while read -r composefile; do
        DIR=$(dirname "$composefile")
        
        # Ignoriere Verzeichnisse, die mit '.' beginnen (z.B. .git, .vscode)
        if [[ "$DIR" == *"/."* ]]; then
            continue
        fi
        
        echo "-----------------------------------------------------"
        echo "Stopping services in: $DIR"
        echo "-----------------------------------------------------"
        (
            # WICHTIG: Lade die .env-Datei aus dem Root-Verzeichnis
            cd "$DIR" && docker compose --env-file ../.env down --remove-orphans
        )
        echo " "
    done
    
    echo "Alle Services wurden heruntergefahren."

else
    # --- FALL 2: EIN ODER MEHR ARGUMENTE ---
    # Stoppe nur die spezifisch angeforderten Services
    
    echo "Spezifische Services zum Stoppen angefordert: $@"
    echo " "
    
    # Iteriere durch JEDES Argument, das dem Skript übergeben wurde
    for SERVICE_NAME in "$@"; do
    
        SERVICE_DIR="./$SERVICE_NAME"
        SERVICE_COMPOSE_FILE="$SERVICE_DIR/compose.yml"
        
        echo "--- Bearbeite Service: $SERVICE_NAME ---"

        # --- Validierung (SRE-Prinzip: Verhindere Fehler) ---
        if [ ! -d "$SERVICE_DIR" ]; then
            echo "!! SRE VALIDATION ERROR !!"
            echo "Verzeichnis nicht gefunden: $SERVICE_DIR"
            echo "-> Service $SERVICE_NAME wird ÜBERSPRUNGEN."
            echo "-----------------------------------------------------"
            echo " "
            continue # Mache mit dem nächsten Argument weiter
        fi
        
        if [ ! -f "$SERVICE_COMPOSE_FILE" ]; then
            echo "!! SRE VALIDATION ERROR !!"
            echo "compose.yml nicht gefunden in $SERVICE_DIR"
            echo "-> Service $SERVICE_NAME wird ÜBERSPRUNGEN."
            echo "-----------------------------------------------------"
            echo " "
            continue # Mache mit dem nächsten Argument weiter
        fi

        # --- Ausfuehrung ---
        echo "Stoppe Services in: $SERVICE_DIR"
        (
            # WICHTIG: Lade die .env-Datei aus dem Root-Verzeichnis
            cd "$DIR" && docker compose --env-file ../.env down --remove-orphans
        )
        echo "-----------------------------------------------------"
        echo " "
    done
    
    echo "Alle angeforderten Services wurden heruntergefahren."
fi

exit 0
