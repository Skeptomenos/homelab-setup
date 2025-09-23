# **n8n with Authelia & Traefik: A Comprehensive SSO Guide**

This guide provides a complete, tested solution for securing an n8n instance with Authelia as a Single Sign-On (SSO) provider, using Traefik as the reverse proxy. It addresses the common browser authentication pop-up and provides instructions for embedding n8n in other applications like Home Assistant.

## **The Problem: A Two-Part Issue**

When integrating n8n with an external SSO provider like Authelia, two distinct issues arise that can prevent a seamless login experience:

1. **Lack of Native SSO Support:** Modern versions of n8n do not natively support trusted header authentication. After a user authenticates with Authelia, n8n remains unaware of their identity and would typically present its own login screen, forcing the user to authenticate a second time.  
2. **The Authentication Pop-up:** Even with a solution for the first issue, a browser-native authentication pop-up is often triggered. This is caused by n8n's internal telemetry endpoints (e.g., /rest/telemetry/...). These specific endpoints have their own authentication mechanism that conflicts with the proxy-based SSO, resulting in n8n sending a 401 Unauthorized response with a WWW-Authenticate: Basic header.

## **The Solution: Hooks & Priority Routing**

The definitive solution requires a two-pronged approach: a custom backend hook for n8n to handle the SSO logic, and a priority-based routing rule in Traefik to bypass authentication for the problematic telemetry endpoints.

### **Step 1: Create the Self-Contained SSO Hook**

Since n8n doesn't natively support trusted header SSO, we must add this functionality using its powerful backend hooks system. This script intercepts requests after they pass through Authelia and manually creates a valid n8n session.

Create a file named hooks.js in your n8n data directory (e.g., ./n8n-data/hooks.js).

**hooks.js**

/\*\*  
 \* n8n External Hook for Trusted Header SSO with Authelia.  
 \*  
 \* SELF-CONTAINED FINAL VERSION \- This script is designed to be robust against  
 \* n8n version changes by avoiding imports of unstable internal functions.  
 \* It manually creates the JWT and cookie.  
 \*/  
console.log('\[HOOKS\] Self-contained hooks.js file loaded by n8n.');

const Layer \= require('router/lib/layer');  
const jwt \= require('jsonwebtoken'); // n8n has this dependency built-in  
const ignoreAuthRegexp \= /^\\/(assets|healthz|webhook|rest\\/oauth2-credentials|rest\\/telemetry)/;

module.exports \= {  
	n8n: {  
		ready: \[  
			async function ({ app, dbCollections, config }) {  
				try {  
					console.log('\[HOOKS\] n8n.ready hook is executing.');  
					const { stack } \= app.router;  
					const index \= stack.findIndex((l) \=\> l.name \=== 'cookieParser');

					if (index \=== \-1) {  
						console.error('\[HOOKS\] ERROR: Could not find cookieParser middleware.');  
						return;  
					}

					stack.splice(index \+ 1, 0, new Layer('/', {  
						strict: false,  
						end: false,  
					}, async (req, res, next) \=\> {  
						try {  
							if (ignoreAuthRegexp.test(req.url) || \!config.get('userManagement.isInstanceOwnerSetUp') || req.cookies?.\['n8n-auth'\]) {  
								return next();  
							}

							const trustedHeader \= process.env.N8N\_FORWARD\_AUTH\_HEADER;  
							if (\!trustedHeader) return next();

							const email \= req.headers\[trustedHeader.toLowerCase()\];  
							if (\!email) return next();

							const user \= await dbCollections.User.findOneByEmail(email);

							if (\!user) {  
								res.statusCode \= 401;  
								res.end(\`User with email ${email} not found in n8n.\`);  
								return;  
							}

							console.log(\`\[HOOKS\] User "${email}" found. Manually issuing SSO cookie.\`);

							const payload \= { id: user.id };  
							const secret \= config.get('security.jwt.secret');  
							const token \= jwt.sign(payload, secret, { expiresIn: '1h' });

							res.cookie('n8n-auth', token, {  
								httpOnly: true,  
								path: '/',  
								sameSite: 'Lax',  
							});

							return next();  
						} catch (error) {  
							console.error('\[HOOKS\] ERROR in middleware:', error);  
							next(error);  
						}  
					}));  
					console.log('\[HOOKS\] Custom self-contained SSO middleware successfully added.');  
				} catch (error) {  
					console.error('\[HOOKS\] CRITICAL ERROR during hook initialization:', error);  
					throw error;  
				}  
			},  
		\],  
	},  
};

### **Step 2: Configure n8n Environment Variables**

Edit your docker-compose.yml file for the n8n service to tell it to load the hook file and which header to trust for the user's email.

\# In your n8n service definition:  
environment:  
  \# ... other environment variables  
  \- N8N\_FORWARD\_AUTH\_HEADER=Remote-Email  
  \- EXTERNAL\_HOOK\_FILES=/home/node/.n8n/hooks.js

### **Step 3: Configure Traefik Priority Routing**

Update the labels section of your n8n service in docker-compose.yml. This configuration creates two routers: a high-priority one to bypass Authelia for telemetry requests and a standard one to secure the main application.

\# In your n8n service definition:  
labels:  
  \# \--- High-priority router for telemetry (bypasses Authelia) \---  
  \- "traefik.enable=true"  
  \- "traefik.http.routers.n8n-telemetry.rule=Host(\`n8n.yourdomain.com\`) && PathPrefix(\`/rest/telemetry\`)"  
  \- "traefik.http.routers.n8n-telemetry.entrypoints=websecure"  
  \- "traefik.http.routers.n8n-telemetry.priority=100"  
  \- "traefik.http.routers.n8n-telemetry.tls=true"  
  \- "traefik.http.routers.n8n-telemetry.tls.certresolver=letsencrypt"  
  \- "traefik.http.routers.n8n-telemetry.service=n8n-service"

  \# \--- Low-priority router for the main app (uses Authelia) \---  
  \- "traefik.http.routers.n8n-main.rule=Host(\`n8n.yourdomain.com\`)"  
  \- "traefik.http.routers.n8n-main.entrypoints=websecure"  
  \- "traefik.http.routers.n8n-main.priority=50"  
  \- "traefik.http.routers.n8n-main.tls=true"  
  \- "traefik.http.routers.n8n-main.tls.certresolver=letsencrypt"  
  \- "traefik.http.routers.n8n-main.middlewares=authelia@docker"  
  \- "traefik.http.routers.n8n-main.service=n8n-service"  
    
  \# \--- Service Definition (shared by both routers) \---  
  \- "traefik.http.services.n8n-service.loadbalancer.server.port=5678"

**Important:** Replace n8n.yourdomain.com with your actual domain.

### **Final Verification**

After applying these changes, restart your n8n container (docker-compose up \-d \--force-recreate n8n). Check the logs (docker logs n8n) to confirm a clean startup. When you navigate to your n8n domain, you should have a seamless SSO experience.

## **Bonus: Embedding n8n in Home Assistant (iframe)**

To allow n8n to be embedded in an iframe on your Home Assistant dashboard, you must address two additional security features: Authelia's SameSite cookie policy and Traefik's Content-Security-Policy header.

### **Step 4: Update Authelia's SameSite Cookie Policy**

For a browser to send the Authelia session cookie to an iframe, the policy must be changed to None. While Lax may work if both services are subdomains of the same parent domain, None is the recommended best practice for maximum compatibility.

1. Open your authelia/config/configuration.yml file.  
2. Find the session configuration block.  
3. Change same\_site: 'lax' to same\_site: 'none'.

**authelia/config/configuration.yml**
~~~
session:  
  \# ... other session settings  
  cookies:  
    \- domain: 'yourdomain.com' \# Your actual domain  
      \# ... other cookie settings  
      same\_site: 'none' \# Changed from 'lax' to 'none' for iframe compatibility

4. Restart the Authelia container for the change to take effect: docker-compose restart authelia.

### **Step 5: Update Traefik Labels to Allow Embedding**

Next, we will define an iframe-headers middleware and apply it to the main n8n router.

1. Open the docker-compose.yml file containing your n8n service.  
2. Update the labels for the n8n-main router to define and apply the new middleware chain.

Update your n8n labels to look like this:

\# In your n8n service definition:  
labels:  
  \# ... (High-priority telemetry router remains the same)  
  \- "traefik.enable=true"  
  \- "traefik.http.routers.n8n-telemetry.rule=Host(\`n8n.${DOMAIN\_PUBLIC}\`) && PathPrefix(\`/rest/telemetry\`)"  
  \- "traefik.http.routers.n8n-telemetry.entrypoints=websecure"  
  \- "traefik.http.routers.n8n-telemetry.priority=100"  
  \- "traefik.http.routers.n8n-telemetry.tls.certresolver=letsencrypt"  
  \- "traefik.http.routers.n8n-telemetry.service=n8n-service"

  \# \--- Low-priority router for the main app (uses Authelia & allows iframe) \---  
  \- "traefik.http.routers.n8n-main.rule=Host(\`n8n.${DOMAIN\_PUBLIC}\`)"  
  \- "traefik.http.routers.n8n-main.entrypoints=websecure"  
  \- "traefik.http.routers.n8n-main.priority=50"  
  \- "traefik.http.routers.n8n-main.tls.certresolver=letsencrypt"  
    
  \# \--- MIDDLEWARE CHAIN \---  
  \# 1\. Define the CSP middleware to allow embedding in Home Assistant  
  \- "traefik.http.middlewares.iframe-headers.headers.contentSecurityPolicy=frame-ancestors 'self' https://home.${DOMAIN\_PUBLIC}"  
  \# 2\. Apply the Authelia middleware AND the new CSP middleware  
  \- "traefik.http.routers.n8n-main.middlewares=authelia@docker,iframe-headers@docker"  
    
  \- "traefik.http.routers.n8n-main.service=n8n-service"  
    
  \# \--- Service Definition (shared by both routers) \---  
  \- "traefik.http.services.n8n-service.loadbalancer.server.port=5678"

~~~

**Important:**

* The variables n8n.${DOMAIN\_PUBLIC} and home.${DOMAIN\_PUBLIC} will be automatically populated from your .env file.  
* The middleware chain authelia@docker,iframe-headers@docker ensures authentication happens first, then the correct security headers are applied to the response.  
3. Restart the n8n container to apply the new labels: docker-compose up \-d \--force-recreate n8n.

After completing these steps, you will be able to add n8n as an iframe panel in Home Assistant, and it will load correctly after you have authenticated with Authelia.