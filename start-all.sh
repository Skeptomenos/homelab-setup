#!/usr/bin/env zsh

# Dieses Skript startet alle Docker Compose-Dienste im homelab-setup-Verzeichnis.

# Finde das Stammverzeichnis des Skripts, damit es von überall aus funktioniert.
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR" || exit

# Definiere den Pfad zur globalen .env-Datei
ENV_FILE_PATH="$(pwd)/.env"

# Überprüfe, ob die .env-Datei existiert
if [ ! -f "$ENV_FILE_PATH" ]; then
    echo "🚨 FEHLER: Globale .env-Datei nicht unter $ENV_FILE_PATH gefunden."
    echo "Bitte erstellen Sie die .env-Datei aus der Vorlage und füllen Sie sie aus."
    exit 1
fi

echo "🚀 Starting all Docker Compose services in homelab-setup..."
echo "    (Using environment file: $ENV_FILE_PATH)"

# Finde alle compose.yml-Dateien NUR in den direkten Unterverzeichnissen.
# Stacks wie 'home-automation' laden ihre eigenen Unterdateien über 'include'.
for compose_file in */compose.yml; do
    # Extrahiere das Verzeichnis aus dem Pfad
    dir=$(dirname "${compose_file}")

    echo "\n--- Found compose file in '$dir'. Starting up... ---"
    # Führe docker compose up aus und übergebe explizit die .env-Datei
    (cd "$dir" && docker compose --env-file "$ENV_FILE_PATH" up -d --force-recreate)
done

echo "\n✅ All services have been started."

