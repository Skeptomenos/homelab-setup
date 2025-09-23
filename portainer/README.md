Portainer - Docker Management UI
This directory contains the compose.yml file to run Portainer Community Edition. Portainer provides a user-friendly web interface to manage all aspects of this Docker environment, including containers, images, volumes, and networks.

Configuration in this Setup
Standalone Service: Portainer is configured as an independent infrastructure service.

Persistent Data: Portainer's configuration is stored in the ./data volume within this directory.

URL: The service is exposed by Traefik and is accessible at https://portainer.local.

Security: Access to the Portainer UI is protected by Authelia. You must first log in via the central Authelia portal before you can reach the Portainer login page.

How to Access
Ensure portainer.local is correctly mapped to 192.168.178.60 in your local hosts file.

Open your web browser and navigate to https://portainer.local.

You will be redirected to the Authelia login page. Log in with your credentials.

After successful authentication, you will be forwarded to the Portainer UI.

Log in to Portainer with the local admin credentials you created during its initial setup.

Note: Since we use a self-signed SSL certificate, your browser will show a security warning on the first visit. You must accept the risk to proceed.

Initial Setup (First Use Only)
When you access Portainer for the first time, you will be prompted to:

Create an initial administrator user account. Choose a strong password.

Connect to a Docker environment. Select the "Docker" option to manage the local Docker instance via its socket (/var/run/docker.sock).

Managing the Portainer Service
All commands to manage the Portainer container should be run from this directory (/srv/docker/portainer/).

Start or update Portainer:

docker compose up -d

Stop Portainer:

docker compose down

View logs:

docker compose logs -f

Restart Portainer:

docker compose restart
