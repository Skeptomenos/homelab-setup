# **Diun (Docker Image Update Notifier)**

## **Overview**

Diun is a service that monitors Docker registries for new images and sends notifications when updates are available for your running (or stopped) containers.

In our setup, Diun is the "trigger" for our automated update workflow. It does not perform updates itself; it only sends a webhook to **n8n**, which then orchestrates an AI-powered changelog review and (if approved) triggers the update via our start-all.sh script.

## **Configuration Analysis**

This service's configuration is split into two files, adhering to our "Centralized Configuration" \[cite: 9\] and "Separation of Concerns" principles.

### **1\. compose.yml (The System Integration)**

This file defines *how* the Diun container integrates with our host system and other services.

* **image: crazymax/diun:latest**: We use the latest tag as recommended by the official documentation \[cite: 5\].  
* **command: serve**: This command is **mandatory**. It instructs Diun to start as a persistent service and load its configuration from the diun.yml file, rather than from environment variables \[cite: 5\].  
* **environment:**:  
  * PUID=${PUID}, PGID=${PGID}, TZ=${TZ}: We *only* pass system-level variables. These are loaded by our start-all.sh script \[cite: 138\] from the global /docker/.env file \[cite: 9\]. This ensures correct file permissions for ./data and correct timezones for the cron schedule.  
* **volumes:**:  
  * **/var/run/docker.sock:/var/run/docker.sock:ro**: This is the Docker provider \[cite: 8\]. It grants Diun read-only (:ro) access to the host's Docker socket, allowing it to see what containers are running.  
  * **./data:/data:Z**: This is the persistent database where Diun stores image manifests. The :Z flag is **mandatory** for SELinux \[cite: 9\] to grant the container permission to write to this host directory.  
  * **./diun.yml:/diun.yml:ro,Z**: This is the most critical part. We mount our custom configuration file into the container. It is mounted read-only (:ro) for security, and with the :Z flag for SELinux compliance.  
* **networks:**:  
  * proxy-netzwerk: This is **mandatory** so that Diun can resolve and send webhooks to http://n8n:5678... using Docker's internal DNS.

### **2\. diun.yml (The Application Logic)**

This file defines *what* Diun does. Using this file solves all previous FTL (Fatal) errors caused by environment variable parsing failures \[cite: 133, 134\].

* **watch:**:  
  * schedule: "0 3 \* \* \*": Defines our desired check-in time (3:00 AM) \[cite: 2\].  
* **providers.docker:**:  
  * watchByDefault: false: This is the **core SRE safety policy** of our setup \[cite: 8, 140\]. Diun is instructed to ignore *all* containers by default.  
* **notif.webhook:**:  
  * endpoint: "http://n8n:5678/...": We use the internal container name (n8n) and port (5678) \[cite: 4\]. This is secure, fast, and does not rely on our public-facing Traefik proxy.

## **SRE Policy & How to Use**

This service follows a **"Default-Deny"** security model.

**By default, Diun monitors ZERO containers.**

This is an intentional safety feature (watchByDefault: false) to prevent Diun from triggering automated updates on our critical infrastructure (Traefik, Authelia, Cloudflared) \[cite: 140\].

### **How to Monitor a New (Non-Critical) Service**

To enable Diun monitoring for a service (e.g., wikijs), you must explicitly "opt-in" by adding a Docker Label to that service's compose.yml file.

1. Open the compose.yml for the service you want to monitor (e.g., /docker/wikijs/compose.yml).  
2. Add the diun.enable=true label:

```

services:
  wikijs:
    image: lscr.io/linuxserver/wikijs:latest
    container_name: wikijs
    # ... other configuration ...
    labels:
      # --- ADD THIS LINE ---
      - "diun.enable=true"

      # (Your other Traefik/Authelia labels)
      - "traefik.enable=true"
      # ...

```

5.   
   Restart that service to apply the new label:

```

# From the /docker directory
./start-all.sh wikijs

```

Diun will automatically detect the new label on its next run.

## **Troubleshooting**

* **Log Message:** WRN No image found  
  * **Meaning:** This is **normal behavior**. It means Diun is running correctly but has not found any containers with the diun.enable=true label.  
* **Log Message:** FTL Cannot load configuration...  
  * **Meaning:** This error is **resolved**. It was caused by our previous attempts to configure Diun with environment variables. The move to diun.yml fixed this. If you see this, your container is running an old, failed configuration.  
* **Symptom:** Diun is running, but n8n never receives a webhook.  
  * **Check 1:** Did you add the diun.enable=true label to any containers?  
  * **Check 2:** Is the n8n workflow "Active" in the n8n UI?  
  * **Check 3:** Are both diun and n8n in the proxy-netzwerk?

