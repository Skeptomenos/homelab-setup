# **Pi-hole with Traefik & Authelia: A Comprehensive Setup Guide**

This document describes the setup and configuration of the **Pi-hole** Docker container as a network-wide DNS ad-blocker. It provides a complete, tested solution for running Pi-hole behind a Traefik Reverse Proxy, secured with Authelia for authentication.

Pi-hole intercepts DNS requests on the local network and blocks requests to known advertising and tracking domains before they reach client devices. The admin web interface is routed through the Traefik Reverse Proxy and secured with Authelia.

The guide covers the initial host setup on Fedora, the Docker Compose configuration, and advanced Traefik routing for both local and secure public access, including a solution for embedding Pi-hole in other dashboards like Home Assistant.

## **Table of Contents**

1. [Prerequisites](https://www.google.com/search?q=%23prerequisites)  
2. [Directory Structure](https://www.google.com/search?q=%23directory-structure)  
3. [Host Preparation (Fedora)](https://www.google.com/search?q=%23step-1-host-preparation-fedora)  
4. [Docker Compose Configuration](https://www.google.com/search?q=%23step-2-docker-compose-configuration)  
5. [Initial Setup & Password](https://www.google.com/search?q=%23step-3-initial-setup--password)  
6. [Usage and Verification](https://www.google.com/search?q=%23step-4-usage-and-verification)

### **Prerequisites**

* A working Docker and Docker Compose environment.  
* A pre-existing Traefik stack with a Docker network named proxy-netzwerk.  
* A pre-existing Authelia container connected to the proxy-netzwerk and configured for your domain.  
* An .env file in a parent directory containing your global variables (PUID, PGID, TZ, DOMAIN\_PUBLIC, DOMAIN\_LOCAL, SUBDOMAIN\_PIHOLE, etc.).

### **Directory Structure**

The entire configuration for this service is located at /srv/docker/pihole/.

```
/srv/docker/└── pihole/    ├── compose.yml    ├── etc-pihole/         # Pi-hole configuration data (persistent)    └── etc-dnsmasq.d/      # Advanced DNS configurations (persistent)
```

### **Step 1: Host Preparation (Fedora)**

Before starting Pi-hole, you must free up **Port 53** on your Fedora host, as it is typically occupied by the \>system's local DNS cache, systemd-resolved.

1\. Stop and Disable the Conflicting Service:  
Run these commands to stop systemd-resolved and prevent it from starting on boot.  
\>sudo systemctl stop systemd-resolved  
\>sudo systemctl disable systemd-resolved

2\. Configure a Fallback DNS:  
Because the system resolver is now off, you must manually tell the host where to send DNS queries.  
\>sudo nano /etc/resolv.conf

Replace the entire content of the file with a public DNS provider, for example:

```
nameserver 1.1.1.1nameserver 1.0.0.1
```

Save and close the file. Your host can now resolve domains, and Port 53 is available for Pi-hole.

### **Step 2: Docker Compose Configuration**

This compose.yml file contains the final, working configuration. It defines the Pi-hole service and all necessary Traefik labels for routing, redirection, and security headers.

Place this file at /srv/docker/pihole/compose.yml.

~~~
# /srv/docker/pihole/compose.yml
# This Compose file sets up a standalone Pi-hole service integrated with Traefik.
services:  
  pihole:    
  image: pihole/pihole:latest    container_name: pihole    restart: unless-stopped    ports:      # Port 53 is required for DNS.      - "53:53/tcp"      - "53:53/udp"    volumes:      - './etc-pihole:/etc/pihole:Z'      - './etc-dnsmasq.d:/etc/dnsmasq.d:Z'    environment:      - PUID=${PUID}      - PGID=${PGID}      - TZ=${TZ}      - WEBPASSWORD=${PIHOLE_WEBPASSWORD}    cap_add:      - NET_ADMIN    dns:      - 1.1.1.1      - 1.0.0.1    networks:      - proxy-netzwerk    labels:      - "traefik.enable=true"      # --- Router for Public, Secure Access (pihole.yourdomain.com) ---      - "traefik.http.routers.pihole-secure.rule=Host(`${SUBDOMAIN_PIHOLE}.${DOMAIN_PUBLIC}`)"      - "traefik.http.routers.pihole-secure.entrypoints=websecure"      - "traefik.http.routers.pihole-secure.tls=true"      - "traefik.http.routers.pihole-secure.tls.certresolver=letsencrypt"      - "traefik.http.routers.pihole-secure.service=pihole-service"            # --- MIDDLEWARE CHAIN ---      # 1. Redirect from / to /admin/      - "traefik.http.middlewares.pihole-redirect.redirectregex.regex=^https?://([^/]+)/?$"      - "traefik.http.middlewares.pihole-redirect.redirectregex.replacement=https://$${1}/admin/"      - "traefik.http.middlewares.pihole-redirect.redirectregex.permanent=true"            # 2. Set the Content-Security-Policy header to allow iFrame embedding in Home Assistant      - "traefik.http.middlewares.pihole-csp.headers.contentSecurityPolicy=frame-ancestors 'self' https://home.${DOMAIN_PUBLIC}"            # 3. Apply the full middleware chain: redirect, CSP header, then authentication.      - "traefik.http.routers.pihole-secure.middlewares=pihole-redirect@docker,pihole-csp@docker,authelia@docker"      # --- Router for Local, Unsecured Access (pihole.yourlocaldomain) ---      - "traefik.http.routers.pihole-local.rule=Host(`${SUBDOMAIN_PIHOLE}.${DOMAIN_LOCAL}`)"      - "traefik.http.routers.pihole-local.entrypoints=http"      - "traefik.http.routers.pihole-local.service=pihole-service"      # Apply only the redirect and CSP middlewares for local access      - "traefik.http.routers.pihole-local.middlewares=pihole-redirect@docker,pihole-csp@docker"      # --- Service Definition (shared by both routers) ---      - "traefik.http.services.pihole-service.loadbalancer.server.port=80"networks:  proxy-netzwerk:    external: true
~~~

### **Step 3: Initial Setup & Password**

1\. Start the Container:  
Navigate to the directory and run the up command.  
\>cd /srv/docker/pihole  
\>docker compose \--env-file ../.env up \-d

2\. Set the Password:  
The WEBPASSWORD environment variable is only used on the first creation. If you need to change the password later, the .env file will have no effect. To reset the password for an existing installation, run:  
\# 1\. Open a shell inside the running container  
\>docker exec \-it pihole /bin/bash

\# 2\. Run the password reset command and follow the prompts  
\>pihole \-a \-p

\# 3\. Exit the container  
\>exit

### **Step 4: Usage and Verification**

* **Public Access:** Navigate to https://pihole.yourdomain.com. Traefik will automatically redirect you to the /admin/ path and then to Authelia for login.  
* **Local Access:** Navigate to http://pihole.yourlocaldomain. Traefik will redirect you to /admin/ without authentication.  
* **Iframe Embedding:** You can now embed the URL https://pihole.yourdomain.com/admin/ in your Home Assistant dashboard, and it will load correctly.  
* **DNS Configuration:** To use Pi-hole for ad-blocking, configure your router or individual devices to use the IP address of your Mac Mini as their DNS server.