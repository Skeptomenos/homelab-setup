# **Traefik & Authelia Proxy-Stack für das Home-Lab**

Dieses Verzeichnis enthält die Konfiguration für den zentralen Proxy- und Sicherheits-Stack unseres Home-Labs. Der Stack besteht aus zwei eng miteinander gekoppelten Diensten, die über eine einzige compose.yml-Datei verwaltet werden, um eine robuste und zuverlässige Startreihenfolge zu gewährleisten.

## **1\. Projektziel & Architektur**

Das Ziel dieses Stacks ist es, eine zentrale, sichere und automatisierte Eingangspforte für alle Web-Dienste im Home-Lab bereitzustellen.

**Kernkomponenten:**

* **Traefik:** Fungiert als moderner Reverse Proxy. Er empfängt den gesamten Web-Traffic, leitet ihn an die entsprechenden internen Dienste weiter und kümmert sich um die automatische Anforderung und Erneuerung von SSL/TLS-Zertifikaten.  
* **Authelia:** Dient als Single Sign-On (SSO) und 2-Faktor-Authentifizierungsportal. Bevor ein Benutzer auf einen geschützten Dienst zugreifen kann, wird er von Traefik an Authelia zur Anmeldung weitergeleitet.

**Architektonisches Prinzip:**

Die Dienste sind in einer einzigen compose.yml-Datei definiert, um die depends\_on und healthcheck-Funktionen von Docker Compose nutzen zu können. Dies löst ein klassisches Problem bei verteilten Setups: Traefik wird **gezwungen**, zu warten, bis Authelia nicht nur gestartet, sondern vollständig betriebsbereit (healthy) ist. Das verhindert Fehler, bei denen Traefik eine nicht existierende authelia-Middleware sucht, weil Authelia noch nicht bereit war.

## **2\. Verzeichnisstruktur**

proxy/  
├── authelia/  
│   └── config/  
│       ├── configuration.yml   \# Hauptkonfiguration für Authelia  
│       ├── users.yaml          \# Benutzer- und Gruppendatenbank  
│       └── db.sqlite3          \# Interne Datenbank von Authelia (wird automatisch erstellt)  
├── traefik/  
│   ├── data/  
│   │   └── acme.json           \# Speicher für Let's Encrypt SSL-Zertifikate  
│   └── traefik.yml             \# Statische Konfiguration für Traefik  
└── compose.yml                 \# Docker Compose Datei für den gesamten Stack

## **3\. Konfiguration im Detail**

### **compose.yml**

Dies ist die Steuerungszentrale des Stacks.

* **services.authelia**:  
  * **volumes**: Bindet das config-Verzeichnis in den Container, um eine persistente Konfiguration zu gewährleisten.  
  * **env\_file**: Lädt globale Geheimnisse (wie den Session Secret) aus der zentralen .env-Datei im Hauptverzeichnis.  
  * **labels**: Hier wird Authelia selbst als Dienst für Traefik deklariert. Außerdem wird hier die authelia-Middleware zentral für alle anderen Dienste definiert.  
  * **healthcheck**: Der entscheidende Block. Er prüft alle 10 Sekunden mit wget, ob die Authelia-API unter http://localhost:9091/api/health antwortet. wget wird anstelle von curl verwendet, da es in minimalistischen Docker-Images wahrscheinlicher vorhanden ist.  
* **services.traefik**:  
  * **depends\_on.authelia.condition: service\_healthy**: Dies ist die wichtigste Zeile für die Stabilität. Sie weist Docker an, den Traefik-Container erst dann zu starten, wenn der healthcheck von Authelia erfolgreich ist.  
  * **environment.CF\_DNS\_API\_TOKEN**: Hier wird der API-Token für Cloudflare sicher als Umgebungsvariable übergeben, damit Traefik die DNS-Challenge für Let's Encrypt durchführen kann.  
  * **volumes**:  
    * ./traefik/traefik.yml: Bindet die statische Konfiguration in den Container.  
    * /var/run/docker.sock: Gibt Traefik die Möglichkeit, andere Docker-Container zu "entdecken" und ihre Labels auszulesen.  
    * ./traefik/data: Persistenter Speicher für die acme.json-Datei.

### **traefik.yml**

Hier wird das Grundverhalten von Traefik definiert.

* **entryPoints**: Definiert die "Türen", an denen Traefik lauscht (http auf Port 80 und websecure auf Port 443).  
* **providers.docker**: Aktiviert die Docker-Integration. exposedByDefault: false ist eine wichtige Sicherheitseinstellung, die sicherstellt, dass nur Container mit dem Label "traefik.enable=true" veröffentlicht werden.  
* **certificatesResolvers.letsencrypt.acme.dnsChallenge**: Dies ist die Konfiguration für die sichere Zertifikatsanforderung. Anstatt Ports zu öffnen (httpChallenge), weist diese Methode Traefik an, sich über die Cloudflare-API zu authentifizieren, um zu beweisen, dass es die Kontrolle über die Domain hat.

### **authelia/config/configuration.yml**

Die Steuerungszentrale für die Authentifizierung.

* **server.address**: Definiert, auf welcher Adresse und welchem Port Authelia im Container lauscht. Die 0.0.0.0-Syntax ist wichtig, damit es von anderen Containern erreicht werden kann.  
* **session.cookies**: Dies ist die moderne und korrekte Art, die Sitzungsdomain zu definieren. Die widersprüchliche, alte domain-Option wurde entfernt, um Startfehler zu vermeiden.  
* **access\_control.rules**: Das Herzstück der Berechtigungslogik.  
  * Die erste Regel (policy: bypass) ist entscheidend. Sie stellt sicher, dass die Login-Seite (auth.helmus.me) selbst nicht durch Authelia geschützt ist.  
  * Die zweite Regel (policy: one\_factor) sichert alle anderen Subdomains (\*.helmus.me) und erlaubt den Zugriff nur für Benutzer, die Mitglied der Gruppe admins sind.  
* **authentication\_backend.file**: Verweist auf die users.yaml-Datei als Quelle für Benutzerinformationen.

## **4\. Nutzung**

**Voraussetzungen:**

1. Eine korrekt ausgefüllte .env-Datei im Hauptverzeichnis (/docker/.env), die die CLOUDFLARE\_DNS\_API\_TOKEN- und die AUTHELIA\_\*-Variablen enthält.  
2. Das externe Docker-Netzwerk proxy-netzwerk muss existieren (docker network create proxy-netzwerk).

**Starten des Stacks:**

\# Navigieren Sie in das /docker/proxy Verzeichnis  
cd /docker/proxy

\# Starten Sie den Stack  
docker compose up \-d

**Überprüfen des Status:**

docker compose ps

Beide Container, authelia und traefik, sollten nach kurzer Zeit den Status (healthy) oder Up anzeigen.

## **5\. Troubleshooting \- Gelernte Lektionen**

Dieser Abschnitt fasst die häufigsten Fehler zusammen, die während der Einrichtung aufgetreten sind, und wie sie gelöst wurden.

| Fehler / Symptom | Ursache | Lösung |
| :---- | :---- | :---- |
| **502 Bad Gateway** auf Diensten | **SELinux (Fedora/RHEL)** blockiert die Netzwerkverbindung zwischen den Containern. | SELinux-Richtlinien für Container installieren (sudo dnf install container-selinux) und die Regel setzen: sudo setsebool \-P container\_network\_connect on. Im Extremfall war ein System-Relabel (sudo touch /.autorelabel && sudo reboot) oder sogar eine Neuinstallation der Richtlinien (sudo dnf reinstall selinux-policy-targeted) notwendig. |
| middleware "authelia@docker" does not exist | Traefik ist gestartet, bevor der Authelia-Container seine Middleware registrieren konnte. | Die Zusammenlegung in einen Stack mit depends\_on und healthcheck hat dieses Problem dauerhaft gelöst. |
| Authelia-Container ist unhealthy | Der healthcheck-Befehl im Container ist nicht vorhanden (curl) oder die Authelia-Konfiguration (configuration.yml) ist fehlerhaft. | Den Healthcheck-Befehl auf wget ändern. Die Authelia-Logs (docker logs authelia) auf fatale Konfigurationsfehler prüfen (z.B. widersprüchliche session.domain- und session.cookies-Optionen). |
| Traefik-Logs: permissions ... for /data/acme.json are too open | Die Zertifikatsdatei ist aus Sicherheitsgründen für andere Benutzer lesbar. Traefik verweigert den Start. | Die korrekten, restriktiven Berechtigungen setzen: chmod 600 /docker/proxy/traefik/data/acme.json. |
| Traefik-Logs: Cannot issue for "\*.homelab.local" | Let's Encrypt kann und darf keine Zertifikate für nicht-öffentliche Domains wie .local ausstellen. | Die Traefik-Router-Regeln (rule=...) so anpassen, dass sie **nur** die öffentliche Domain (\*.helmus.me) verwenden. Der lokale Zugriff funktioniert weiterhin über Split-Brain DNS (Pi-hole). |
| Authelia: "Unendliches Laden" nach dem Login oder "403 Forbidden" | Die Zugriffsregeln in configuration.yml (subject: "group:admins") stimmen nicht mit der Gruppenzugehörigkeit des Benutzers in users.yaml überein. | Den Gruppennamen in der users.yaml-Datei exakt an die Regel anpassen (z.B. admin vs. admins). |
| 404 Page Not Found bei einem Dienst | Der Traefik-Router für den Dienst findet den Zieldienst nicht. | Überprüfen, ob das Label traefik.http.routers.\<router-name\>.service=\<service-name\> in der compose.yml des Zieldienstes korrekt gesetzt ist. |

