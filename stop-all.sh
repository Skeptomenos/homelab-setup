#!/usr/bin/env zsh

# Dieses Skript stoppt alle Docker Compose-Dienste im homelab-setup-Verzeichnis.

# Finde das Stammverzeichnis des Skripts, damit es von überall aus funktioniert.
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR" || exit

# Definiere den Pfad zur globalen .env-Datei
ENV_FILE_PATH="$(pwd)/.env"

# Überprüfe, ob die .env-Datei existiert. Beim Stoppen ist es nur eine Warnung.
if [ ! -f "$ENV_FILE_PATH" ]; then
    echo "⚠️ WARNUNG: Globale .env-Datei nicht unter $ENV_FILE_PATH gefunden."
    echo "    Das Herunterfahren könnte fehlschlagen, wenn Variablen für Netzwerknamen etc. benötigt werden."
fi

echo "🛑 Shutting down all Docker Compose services in homelab-setup..."

# --- KORREKTUR HIER ---
# Finde alle compose.yml-Dateien in den direkten Unterverzeichnissen.
# Der Zusatz (N) ist ein Zsh "glob qualifier", der verhindert, dass das Skript
# abbricht, wenn eines der Suchmuster keine Dateien findet.
for compose_file in */compose.yml(N) */*/compose.yml(N); do
    # Extrahiere das Verzeichnis aus dem Pfad
    dir=$(dirname "${compose_file}")

    echo "\n--- Found compose file in '$dir'. Shutting down... ---"
    # Führe docker compose down aus und übergebe explizit die .env-Datei
    (cd "$dir" && docker compose --env-file "$ENV_FILE_PATH" down)
    echo "--- Services in '$dir' stopped successfully. ---"
done

echo "\n✅ All services have been shut down."
