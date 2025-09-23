# **Secure and Centralized Docker Homelab**

This project implements a secure, robust, and centralized Docker environment for a personal homelab running on a Fedora-based server. The primary goal is to provide Single Sign-On (SSO) protected access to all services from both the local network and the internet, while maintaining a modular, easy-to-manage configuration.

This document serves as the central manual for the architecture, initial setup, integration of new services, and troubleshooting.

## **Table of Contents**

1. [Core Architectural Concepts](https://www.google.com/search?q=%231-core-architectural-concepts)  
2. [Prerequisites](https://www.google.com/search?q=%232-prerequisites)  
3. [Initial Setup](https://www.google.com/search?q=%233-initial-setup)  
4. [Adding a New Service (Blueprint)](https://www.google.com/search?q=%234-adding-a-new-service-blueprint)  
5. [Daily Management & Scripts](https://www.google.com/search?q=%235-daily-management--scripts)  
6. [Troubleshooting](https://www.google.com/search?q=%236-troubleshooting)  
7. [Project Structure](https://www.google.com/search?q=%237-project-structure)

### **1\. Core Architectural Concepts**

This setup is based on four fundamental principles to ensure stability, security, and maintainability:

* **Centralized Configuration (.env file):** All global variables such as domains, subdomains, user IDs, and secrets are defined in a single .env file in the project's root directory. This creates a "Single Source of Truth" and prevents redundant or conflicting configurations.  
* **Consistent Permissions (PUID/PGID & SELinux):** File permission conflicts are avoided through two measures:  
  1. All containers run under the same user ID (PUID) and group ID (PGID), which are defined in the .env file.  
  2. On Fedora systems, the SELinux label :Z is used for all mounted volumes to grant containers write access by correctly relabeling the security context.  
* **Automated Management (Scripts):** The start-all.sh and stop-all.sh scripts in the root directory allow for the management of the entire stack with a single command. They load the global .env file and apply the configuration to all services.  
* **Layered Security (Traefik, Authelia, Cloudflare):**  
  * **Cloudflared:** Establishes a secure tunnel to the internet without needing to open any ports on the router.  
  * **Traefik:** Acts as a reverse proxy that receives all traffic, forwards requests to the correct services based on hostnames, and handles TLS encryption.  
  * **Authelia:** Functions as a central authentication portal (SSO with 2FA) that is placed in front of every service to protect access.

#### **The Security Trio in Detail: The Path of a Request**

Understanding the request flow is crucial to understanding the architecture.

**Request Flow from the Internet (e.g., https://code.your-domain.com)**

1. **DNS & Tunnel Entry (Cloudflare):** Your request is directed to the Cloudflare Tunnel.  
2. **Secure Ingress (cloudflared):** The cloudflared container on your server receives the request and forwards it to Traefik.  
3. **Routing (Traefik):** Traefik inspects the host header and finds the matching router.  
4. **Authentication Middleware (Traefik \-\> Authelia):** Traefik forwards the request to Authelia for verification.  
5. **Authentication Check (Authelia):** Authelia checks your session cookie. If you are not authenticated, you are redirected to the login portal. Upon success, it gives the green light to Traefik.  
6. **Final Forwarding (Traefik \-\> Service):** Traefik forwards the request to the target service (e.g., vscode-server).

**Request Flow from the Local Network (e.g., https://code.homelab.local)**

1. **DNS (/etc/hosts):** Your local machine resolves code.homelab.local to your Docker host's IP address.  
2. **Routing (Traefik):** Your browser sends the request directly to Traefik.  
3. **Authentication (Traefik \-\> Authelia \-\> Service):** From here, the flow is identical to steps 4, 5, and 6 from above.

### **2\. Prerequisites**

* A server with a Fedora-based operating system.  
* Docker and Docker Compose (v2.x) are installed.  
* A Cloudflare account and a configured domain.  
* A Cloudflare Tunnel has been created and the token is available.  
* Git for managing the configuration files.

### **3\. Initial Setup**

1. **Clone the Repository:**  
   git clone \<your-repo-url\> /docker/  
   cd /docker/

2. Create the Global .env File:  
   In the root directory (/docker), create a file named .env and customize the values. Be sure to add this file to your .gitignore\!  
   \# /docker/.env

   \# Global User and Permission Settings  
   PUID=1000  
   PGID=1000  
   UMASK=002  
   TZ=Europe/Berlin

   \# Domain Settings  
   DOMAIN\_LOCAL=homelab.local  
   DOMAIN\_PUBLIC=your-domain.com

   \# Subdomain Aliases  
   SUBDOMAIN\_AUTHELIA=auth  
   SUBDOMAIN\_TRAEFIK=traefik  
   \# ... other subdomains ...

   \# Secrets & Passwords  
   AUTHELIA\_JWT\_SECRET=YOUR\_VERY\_LONG\_AND\_RANDOM\_JWT\_SECRET  
   CLOUDFLARE\_TUNNEL\_TOKEN=YOUR\_CLOUDFLARE\_TUNNEL\_TOKEN  
   \# ... other secrets ...

3. **Create the Shared Docker Network:**  
   docker network create proxy-netzwerk

4. **Set File Permissions:**  
   sudo chown \-R 1000:1000 .

5. **Make Scripts Executable:**  
   chmod \+x start-all.sh  
   chmod \+x stop-all.sh

6. **Start the Entire Stack for the First Time:**  
   ./start-all.sh

### **4\. Adding a New Service (Blueprint)**

Follow these steps to seamlessly integrate a new service (e.g., fileserver).

1. Create Directory and compose.yml:  
   Create a new directory (e.g., /docker/fileserver) and a compose.yml file inside it. Use the following template, which employs the best-practice pattern with two routers.  
   \# /docker/fileserver/compose.yml  
   services:  
     fileserver:  
       image: some/fileserver-image:latest  
       container\_name: fileserver  
       restart: unless-stopped  
       environment:  
         \- PUID=${PUID}  
         \- PGID=${PGID}  
         \- TZ=${TZ}  
       volumes:  
         \- ./config:/config:Z  
         \- /path/to/your/data:/data:Z  
       networks:  
         \- proxy-netzwerk  
       labels:  
         \- "traefik.enable=true"

         \# \--- Router for public, secure access \---  
         \- "traefik.http.routers.fileserver-secure.rule=Host(\`${SUBDOMAIN\_FILESERVER}.${DOMAIN\_PUBLIC}\`)"  
         \- "traefik.http.routers.fileserver-secure.entrypoints=websecure"  
         \- "traefik.http.routers.fileserver-secure.tls=true"  
         \- "traefik.http.routers.fileserver-secure.tls.certresolver=letsencrypt"  
         \- "traefik.http.routers.fileserver-secure.middlewares=authelia@docker"  
         \- "traefik.http.routers.fileserver-secure.service=fileserver-service"

         \# \--- Router for local access \---  
         \- "traefik.http.routers.fileserver-local.rule=Host(\`${SUBDOMAIN\_FILESERVER}.${DOMAIN\_LOCAL}\`)"  
         \- "traefik.http.routers.fileserver-local.entrypoints=http" \# Or 'websecure' if you have a local TLS certificate  
         \- "traefik.http.routers.fileserver-local.service=fileserver-service"

         \# \--- Service Definition (used by both routers) \---  
         \- "traefik.http.services.fileserver-service.loadbalancer.server.port=8080" \# \<-- Adjust the internal port of the service\!

   networks:  
     proxy-netzwerk:  
       external: true

2. Define Subdomain in .env:  
   Open /docker/.env and add: SUBDOMAIN\_FILESERVER=files  
3. Configure Access in Authelia:  
   Open /docker/proxy/authelia/config/configuration.yml and add a new rule.  
4. Add Local DNS Entry:  
   Edit the hosts file on your client computer and add 192.168.1.10 files.homelab.local (replace the IP).  
5. Restart Services:  
   Run ./start-all.sh.

### **5\. Daily Management & Scripts**

The management scripts simplify the operation of the entire stack.

**start-all.sh**

\#\!/usr/bin/env zsh  
\# This script starts all Docker Compose services in the homelab-setup directory.

\# Find the script's root directory to make it runnable from anywhere.  
SCRIPT\_DIR=$(dirname "$0")  
cd "$SCRIPT\_DIR" || exit

\# Define the path to the global .env file  
ENV\_FILE\_PATH="$(pwd)/.env"

\# Check if the .env file exists  
if \[ \! \-f "$ENV\_FILE\_PATH" \]; then  
    echo "🚨 ERROR: Global .env file not found at $ENV\_FILE\_PATH."  
    echo "Please create the .env file from the template and fill it out."  
    exit 1  
fi

echo "🚀 Starting all Docker Compose services in homelab-setup..."  
echo "    (Using environment file: $ENV\_FILE\_PATH)"

\# Find all compose.yml files ONLY in the direct subdirectories.  
\# Stacks like 'home-automation' load their own sub-files via 'include'.  
for compose\_file in \*/compose.yml; do  
    \# Extract the directory from the path  
    dir=$(dirname "${compose\_file}")

    echo "\\n--- Found compose file in '$dir'. Starting up... \---"  
    \# Execute docker compose up, explicitly passing the .env file  
    (cd "$dir" && docker compose \--env-file "$ENV\_FILE\_PATH" up \-d \--force-recreate)  
done

echo "\\n✅ All services have been started."

**stop-all.sh**

\#\!/usr/bin/env zsh  
\# This script stops all Docker Compose services in the homelab-setup directory.

\# Find the script's root directory to make it runnable from anywhere.  
SCRIPT\_DIR=$(dirname "$0")  
cd "$SCRIPT\_DIR" || exit

\# Define the path to the global .env file  
ENV\_FILE\_PATH="$(pwd)/.env"

\# Check if the .env file exists. It's only a warning on shutdown.  
if \[ \! \-f "$ENV\_FILE\_PATH" \]; then  
    echo "⚠️ WARNING: Global .env file not found at $ENV\_FILE\_PATH."  
    echo "    Shutdown might fail if variables are needed for network names, etc."  
fi

echo "🛑 Shutting down all Docker Compose services in homelab-setup..."

\# Find all compose.yml files in direct and second-level subdirectories.  
\# The (N) is a Zsh "glob qualifier" that prevents the script from failing  
\# if one of the search patterns doesn't find any files.  
for compose\_file in \*/compose.yml(N) \*/\*/compose.yml(N); do  
    \# Extract the directory from the path  
    dir=$(dirname "${compose\_file}")

    echo "\\n--- Found compose file in '$dir'. Shutting down... \---"  
    \# Execute docker compose down, explicitly passing the .env file  
    (cd "$dir" && docker compose \--env-file "$ENV\_FILE\_PATH" down)  
    echo "--- Services in '$dir' stopped successfully. \---"  
done

echo "\\n✅ All services have been shut down."

### **6\. Troubleshooting**

* **Error: "Permission Denied"**: Stop services (./stop-all.sh), run sudo chown \-R 1000:1000 . in the root directory, and ensure all volumes have the :Z label.  
* **Error: 404 Not Found**: Check the rule labels in the compose.yml for typos and clear your browser cache.  
* **Error: 502 Bad Gateway**: Ensure the target service is running, connected to proxy-netzwerk, and the loadbalancer.server.port label is correct.  
* **Error: "address already in use" for Port 53 (Pi-hole)**: Disable systemd-resolved on the host: sudo systemctl stop systemd-resolved and sudo systemctl disable systemd-resolved.

### **7\. Project Structure**

The project is structured modularly to ensure a clear separation of concerns.

/docker/  
├── .env                  \# Global configuration and secrets  
├── .gitignore  
├── README.md             \# This document  
├── start-all.sh          \# Script to start all services  
├── stop-all.sh           \# Script to stop all services  
├── home-automation/      \# Stack for Smart Home  
│   └── compose.yml  
├── n8n/  
│   └── compose.yml  
├── pihole/  
│   └── compose.yml  
├── portainer/  
│   └── compose.yml  
├── proxy/                \# Consolidated Ingress Stack  
│   ├── compose.yml  
│   ├── authelia/  
│   ├── cloudflared/  
│   └── traefik/  
├── teslalogger/  
│   └── compose.yml  
└── vscode-server/  
    └── compose.yml  
