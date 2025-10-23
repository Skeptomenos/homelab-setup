#!/bin/bash

# SRE Homelab - Master Start Script
# Dieses Skript stellt sicher, dass die globale .env-Datei (Single Source of Truth)
# *immer* korrekt geladen wird.
#
# USAGE:
#   ./start-all.sh               (Startet ALLE Services in allen Unterverzeichnissen)
#   ./start-all.sh diun          (Startet NUR den Service im Verzeichnis ./diun)
#   ./start-all.sh diun n8n ...  (Startet alle angegebenen Services nacheinander)

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
    echo "Kann keine Services ohne Konfiguration starten."
    echo "-----------------------------------------------------"
    exit 1
fi

echo "Global .env file found. Proceeding..."
echo " "

# --- Argumenten-Handling ---

if [ $# -eq 0 ]; then
    # --- FALL 1: KEINE ARGUMENTE ---
    # Starte alle Services (bisheriges Verhalten)
    
    echo "Kein spezifischer Service angefordert. Starte ALLE Services..."

    find . -mindepth 2 -name 'compose.yml' | while read -r composefile; do
        DIR=$(dirname "$composefile")
        
        # Ignoriere Verzeichnisse, die mit '.' beginnen (z.B. .git, .vscode)
        if [[ "$DIR" == *"/."* ]]; then
            continue
        fi
        
        echo "-----------------------------------------------------"
        echo "Starting services in: $DIR"
        echo "-----------------------------------------------------"
        (
            # WICHTIG: Lade die .env-Datei aus dem Root-Verzeichnis
            cd "$DIR" && docker compose --env-file ../.env up -d --remove-orphans
        )
        echo " "
    done
    
    echo "Alle Services wurden verarbeitet."

else
    # --- FALL 2: EIN ODER MEHR ARGUMENTE ---
    # Starte nur die spezifisch angeforderten Services
    
    echo "Spezifische Services angefordert: $@"
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
        echo "Starte Services in: $SERVICE_DIR"
        (
            # WICHTIG: Lade die .env-Datei aus dem Root-Verzeichnis
            cd "$SERVICE_DIR" && docker compose --env-file ../.env up -d --remove-orphans
        )
        echo "-----------------------------------------------------"
        echo " "
    done
    
    echo "Alle angeforderten Services wurden verarbeitet."
fi

exit 0