# **n8n with Native Authentication & Traefik**

This guide provides a complete, tested solution for running a stable and secure n8n instance using its built-in authentication, with Traefik as the reverse proxy. This setup prioritizes reliability and ease of maintenance over Single Sign-On (SSO).

## **Architectural Decision: Why Not Use Authelia SSO?**

Previous versions of this setup attempted to secure n8n using Authelia SSO. This required a complex workaround because the community version of n8n does not natively support the trusted header authentication method used by SSO providers like Authelia.

The workaround involved two technical challenges:

1. **Lack of Native SSO Support:** After a user authenticated with Authelia, n8n remained unaware of their identity and would present its own login screen, forcing a second login.  
2. **The Authentication Pop-up:** n8n's internal telemetry endpoints (e.g., /rest/telemetry/...) use their own authentication mechanism that conflicted with the proxy-based SSO, causing n8n to send a 401 Unauthorized response that triggered a disruptive browser login pop-up.

The solution was to implement a custom hooks.js script to manually create n8n sessions and use priority-based routing in Traefik to bypass Authelia for the problematic telemetry endpoints.

However, this approach proved to be **fundamentally unstable** for several reasons:

* **Extreme Fragility:** The hooks.js script depended on n8n's internal, undocumented APIs. These APIs changed without warning between n8n versions, causing the entire instance to fail with "Internal Server Errors" after routine updates.  
* **High Maintenance Burden:** Each n8n update required a significant debugging effort to reverse-engineer the internal changes and patch the script. This turned simple maintenance into a time-consuming development task.  
* **Unreliable Execution:** Even with a patched script, the timing and availability of n8n's internal objects proved to be inconsistent, leading to a frustrating and persistent cycle of errors.

**Conclusion:** For a critical homelab service where reliability is paramount, the hooks.js workaround is not a sustainable long-term solution. The decision was made to switch to n8n's robust, officially supported basic authentication. This sacrifices the convenience of SSO for this one service in exchange for rock-solid stability and zero-maintenance updates.

## **Current Configuration: Native Basic Authentication**

The current setup is simpler and more reliable. Traefik handles routing and SSL, while n8n manages its own user access.

### **Step 1: Configure n8n Environment Variables**

The core of the configuration is handled by environment variables passed from the central ../.env file. Ensure the following variables are set in your .env file:

* **N8N\_BASIC\_AUTH\_ACTIVE=true**: Enables n8n's built-in login screen.  
* **N8N\_BASIC\_AUTH\_USER**: The username you will use to log in.  
* **N8N\_BASIC\_AUTH\_PASSWORD**: The password for the user. Choose a strong, unique password.  
* **N8N\_ENCRYPTION\_KEY**: A long, random key for encrypting credentials.  
* **N8N\_JWT\_SECRET**: A long, random key for signing session tokens.

### **Step 2: Configure Traefik Routing**

The Traefik configuration is now greatly simplified. We use a single router for the entire n8n application that does **not** include the authelia@docker middleware.

The labels in the compose.yml file handle this automatically:

    labels:  
      \- "traefik.enable=true"  
      \# This is now the main router for the entire application.  
      \- "traefik.http.routers.n8n-main.rule=Host(\`n8n.${DOMAIN\_PUBLIC}\`)"  
      \- "traefik.http.routers.n8n-main.entrypoints=websecure"  
      \- "traefik.http.routers.n8n-main.tls=true"  
      \- "traefik.http.routers.n8n-main.tls.certresolver=letsencrypt"  
      \- "traefik.http.routers.n8n-main.service=n8n-service"  
      \# ... service definition

### **Step 3: Accessing n8n**

1. Start the n8n stack (docker compose \--env-file ../.env up \-d).  
2. Navigate to your n8n URL (e.g., https://n8n.helmus.me).  
3. You will be presented with the standard n8n login prompt.  
4. Enter the N8N\_BASIC\_AUTH\_USER and N8N\_BASIC\_AUTH\_PASSWORD you defined in your .env file to log in.

## **Embedding n8n in Home Assistant (iframe)**

To allow n8n to be embedded in an iframe on your Home Assistant dashboard, you must apply a custom Content-Security-Policy header. This is handled by a Traefik middleware defined in the compose.yml file.

    labels:  
      \# ... other labels  
      \# 1\. Define the CSP middleware to allow embedding in Home Assistant  
      \- "traefik.http.middlewares.iframe-headers.headers.contentSecurityPolicy=frame-ancestors 'self' https://home.${DOMAIN\_PUBLIC}"  
      \# 2\. Apply ONLY the CSP middleware.  
      \- "traefik.http.routers.n8n-main.middlewares=iframe-headers@docker"

This configuration ensures that browsers will permit the n8n UI to be rendered inside your Home Assistant dashboard while still being protected by n8n's own login system.