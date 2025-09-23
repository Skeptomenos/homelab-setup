# **TeslaLogger Multi-Container Setup**

This directory contains the configuration for **TeslaLogger**, using the official multi-container setup. This stack is fully integrated into the homelab architecture, with its web interfaces exposed via Traefik and secured by Authelia.

## **Architecture Overview**

This setup consists of several interconnected services defined in the compose.yml file:

* **teslalogger**: The core application that polls data from your Tesla.  
* **teslalogger-database**: A MariaDB container to store all collected data.  
* **teslalogger-grafana**: A Grafana instance pre-configured for visualizing the data.  
* **teslalogger-webserver**: Provides the main admin web interface.  
* **teslalogger-watchtower**: An optional service to automatically update the containers in this stack.

### **Network and Security**

* **Internal Communication**: All services communicate with each other over a private, internal Docker network (default).  
* **External Access**: The teslalogger-webserver and teslalogger-grafana containers are also connected to the proxy-netzwerk, allowing Traefik to route traffic to them.  
* **Authentication**: All web interfaces are protected by Authelia.

## **Accessing TeslaLogger Interfaces**

There are two primary web interfaces, both secured by Authelia:

1. **Main Admin Panel**:  
   * **URL**: https://teslalogger.local (and/or https://teslalogger.helmus.me)  
   * **Purpose**: Main configuration, vehicle settings, and updates.  
2. **Grafana Dashboards**:  
   * **URL**: https://tesla-grafana.local (and/or https://tesla-grafana.helmus.me)  
   * **Purpose**: Viewing detailed charts, graphs, and historical data.

## **Configuration Management**

### **Passwords and Secrets**

* **.env file**: All sensitive information, such as database passwords, is stored in the .env file within this directory. This file is **not** committed to Git and should be managed securely.  
* **Grafana Admin Password**: The admin password for the Grafana UI is set in the environment section of the teslalogger-grafana service in the compose.yml file.

### **Persistent Data**

* **Docker Volumes**: This setup uses Docker-managed named volumes (e.g., teslalogger-net8-data, teslalogger-net8-grafanadashboards) to store all persistent data. This is the recommended approach as Docker handles the storage and permissions.  
* **Host-mounted Volumes**: Certain paths, like ${APPDATA\_PATH:-.}/mysql, are mounted directly from the host for data like backups and invoices.

## **Managing the TeslaLogger Stack**

All commands to manage this stack should be run from within this directory (/srv/docker/teslalogger/).

* **Start or update the stack:**  
  docker compose up \-d

* **Stop the stack:**  
  docker compose down

* **View logs for all services:**  
  docker compose logs \-f

* **View logs for a specific service (e.g., Grafana):**  
  docker compose logs \-f teslalogger-grafana  

Approach follows install guide from https://github.com/bassmaster187/TeslaLogger/blob/master/docker_setup.md, renames services and adds relevant traefik labels