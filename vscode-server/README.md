# **VS Code Server Service**

This directory contains the configuration for the code-server service, which provides a full-featured Visual Studio Code editor accessible from a web browser.

## **Purpose in this Homelab**

The primary role of this VS Code Server instance is to provide a centralized, consistent, and easily accessible environment for managing all the configuration files (compose.yml, .env, etc.) for the entire homelab setup. It runs as a container and has the \~/homelab-setup directory mounted, allowing you to edit any file in the project directly.

## **Service Configuration (compose.yml)**

The compose.yml file in this directory is configured to integrate seamlessly with the homelab's core infrastructure. Here are the key configuration points:

* **User Permissions (PUID/PGID):** The service is configured to run as user and group 1000\. This is critical to ensure it has the same permissions as your host user, preventing "Permission Denied" errors when saving files or using Git.  
* **Volumes:**  
  * ./config:/config:Z: This persists the VS Code Server's own settings, extensions, and user data within this directory.  
  * \~/homelab-setup:/config/workspace:Z: This mounts the entire project directory into the container's default workspace, making all files immediately available upon opening the editor.  
  * **:Z Flag**: This flag is **mandatory** on Fedora/RHEL systems. It tells Docker to apply the correct SELinux security context to the mounted volumes, allowing the container to read and write to them.  
* **Traefik Labels:** The labels automatically configure Traefik to expose this service on vscode.homelab.local and vscode.helmus.me.  
* **Security:** The authelia@docker middleware label ensures that access to the editor is protected by your central Authelia SSO, requiring a valid login.

## **Accessing the Service**

1. **Local Access:** Navigate to https://vscode.homelab.local  
2. **Remote Access:** Navigate to https://vscode.helmus.me

You will be prompted to log in via Authelia if you do not have an active session.

## **Troubleshooting**

The most common issue with this service is related to file permissions. If you encounter errors saving files, using the integrated terminal, or performing Git operations, please refer to the **"Permission Denied" or Git Errors** section in the main README.md at the root of the homelab-setup project for the standard fix procedure.