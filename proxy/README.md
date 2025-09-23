# **Traefik & Authelia Proxy Stack for the Homelab**

This directory contains the configuration for the central proxy and security stack of our homelab. The stack consists of two tightly coupled services managed via a single compose.yml file to ensure a robust and reliable startup sequence.

## **1\. Project Goal & Architecture**

The goal of this stack is to provide a central, secure, and automated entry point for all web services in the homelab.

**Core Components:**

* **Traefik:** Functions as a modern reverse proxy. It receives all web traffic, forwards it to the appropriate internal services, and handles the automatic request and renewal of SSL/TLS certificates.  
* **Authelia:** Serves as a Single Sign-On (SSO) and 2-Factor Authentication portal. Before a user can access a protected service, Traefik forwards them to Authelia for login.

**Architectural Principle:**

The services are defined in a single compose.yml file to leverage Docker Compose's depends\_on and healthcheck features. This solves a classic problem in distributed setups: Traefik is **forced** to wait until Authelia is not just started, but fully operational (healthy). This prevents errors where Traefik searches for a non-existent authelia middleware because Authelia was not yet ready.

## **2\. Directory Structure**

proxy/  
├── authelia/  
│   └── config/  
│       ├── configuration.yml   \# Main configuration for Authelia  
│       ├── users.yaml          \# User and group database  
│       └── db.sqlite3          \# Authelia's internal database (created automatically)  
├── traefik/  
│   ├── data/  
│   │   └── acme.json           \# Storage for Let's Encrypt SSL certificates  
│   └── traefik.yml             \# Static configuration for Traefik  
└── compose.yml                 \# Docker Compose file for the entire stack

## **3\. Configuration in Detail**

### **compose.yml**

This is the control center of the stack.

* **services.authelia**:  
  * **volumes**: Binds the config directory into the container to ensure persistent configuration.  
  * **env\_file**: Loads global secrets (like the Session Secret) from the central .env file in the main directory.  
  * **labels**: Declares Authelia itself as a service for Traefik. Additionally, this is where the authelia middleware is centrally defined for all other services.  
  * **healthcheck**: The crucial block. It checks every 10 seconds with wget to see if the Authelia API responds at http://localhost:9091/api/health. wget is used instead of curl as it is more likely to be present in minimalist Docker images.  
* **services.traefik**:  
  * **depends\_on.authelia.condition: service\_healthy**: This is the most important line for stability. It instructs Docker to start the Traefik container only after Authelia's healthcheck is successful.  
  * **environment.CF\_DNS\_API\_TOKEN**: The API token for Cloudflare is securely passed as an environment variable, allowing Traefik to perform the DNS challenge for Let's Encrypt.  
  * **volumes**:  
    * ./traefik/traefik.yml: Binds the static configuration into the container.  
    * /var/run/docker.sock: Allows Traefik to "discover" other Docker containers and read their labels.  
    * ./traefik/data: Persistent storage for the acme.json file.

### **traefik.yml**

This file defines the basic behavior of Traefik.

* **entryPoints**: Defines the "doors" where Traefik listens (http on port 80 and websecure on port 443).  
* **providers.docker**: Activates Docker integration. exposedByDefault: false is a critical security setting that ensures only containers with the label "traefik.enable=true" are published.  
* **certificatesResolvers.letsencrypt.acme.dnsChallenge**: This is the configuration for secure certificate acquisition. Instead of opening ports (httpChallenge), this method instructs Traefik to authenticate via the Cloudflare API to prove it controls the domain.

### **authelia/config/configuration.yml**

The control center for authentication.

* **server.address**: Defines the address and port on which Authelia listens inside the container. The 0.0.0.0 syntax is important so it can be reached by other containers.  
* **session.cookies**: This is the modern and correct way to define the session domain. The conflicting, old domain option has been removed to prevent startup errors.  
* **access\_control.rules**: The heart of the permission logic.  
  * The first rule (policy: bypass) is critical. It ensures that the login page itself (auth.helmus.me) is not protected by Authelia.  
  * The second rule (policy: one\_factor) secures all other subdomains (\*.helmus.me) and grants access only to users who are members of the admins group.  
* **authentication\_backend.file**: Points to the users.yaml file as the source for user information.

## **4\. Usage**

**Prerequisites:**

1. A correctly filled-out .env file in the main directory (/docker/.env) containing the CLOUDFLARE\_DNS\_API\_TOKEN and AUTHELIA\_\* variables.  
2. The external Docker network proxy-netzwerk must exist (docker network create proxy-netzwerk).

**Starting the Stack:**

\# Navigate to the /docker/proxy directory  
cd /docker/proxy

\# Start the stack  
docker compose up \-d

**Checking the Status:**

docker compose ps

Both containers, authelia and traefik, should show a status of (healthy) or Up after a short time.

## **5\. Troubleshooting \- Lessons Learned**

This section summarizes the most common errors encountered during setup and how they were resolved.

| Error / Symptom | Cause | Solution |
| :---- | :---- | :---- |
| **502 Bad Gateway** on services | **SELinux (Fedora/RHEL)** blocks the network connection between containers. | Install SELinux policies for containers (sudo dnf install container-selinux) and set the rule: sudo setsebool \-P container\_network\_connect on. In extreme cases, a system relabel (sudo touch /.autorelabel && sudo reboot) or even reinstalling the policies (sudo dnf reinstall selinux-policy-targeted) was necessary. |
| middleware "authelia@docker" does not exist | Traefik started before the Authelia container could register its middleware. | Consolidating into a single stack with depends\_on and healthcheck has permanently solved this problem. |
| Authelia container is unhealthy | The healthcheck command is not present in the container (curl) or the Authelia configuration (configuration.yml) is faulty. | Change the healthcheck command to wget. Check the Authelia logs (docker logs authelia) for fatal configuration errors (e.g., conflicting session.domain and session.cookies options). |
| Traefik Logs: permissions ... for /data/acme.json are too open | The certificate file is readable by other users for security reasons. Traefik refuses to start. | Set the correct, restrictive permissions: chmod 600 /docker/proxy/traefik/data/acme.json. |
| Traefik Logs: Cannot issue for "\*.homelab.local" | Let's Encrypt cannot and will not issue certificates for non-public domains like .local. | Adjust the Traefik router rules (rule=...) to **only** use the public domain (\*.helmus.me). Local access continues to work via Split-Brain DNS (Pi-hole). |
| Authelia: "Infinite loading" after login or "403 Forbidden" | The access control rules in configuration.yml (e.g., subject: "group:admins") do not match the user's group membership in users.yaml. | Ensure the group name in the users.yaml file exactly matches the rule (e.g., admin vs. admins). |
| 404 Page Not Found for a service | The Traefik router for the service cannot find the target service. | Verify that the label traefik.http.routers.\<router-name\>.service=\<service-name\> is set correctly in the target service's compose.yml. |

