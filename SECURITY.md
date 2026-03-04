# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, **please do not open a public issue.** Instead, report it privately by emailing: **damian.kozlowski@piatnica.com.pl**.

Please include the following in your report:

* A detailed description of the vulnerability.
* Steps to reproduce the issue.
* Potential impact.


## Architecture & Threat Model Context

To assist security researchers, please note the intended security architecture of this platform:

* **Surface Area:** Only the Caddy reverse proxy (Ports `80` / `443`) and the Forgejo SSH interface (Port `222`) are exposed to the external network.
* **Network Isolation:** Most user-facing web services (JupyterHub, Grafana, Authelia) do not bind to host ports at all; they operate strictly within internal Docker bridge networks. Forgejo's web API is an exception, bound locally to `127.0.0.1:3000`.
* **Backend Isolation:** State and telemetry backends (PostgreSQL, Valkey, Grafana Alloy, Prometheus, Loki) are isolated on a separate backend Docker network (`ds-backend-net`) or strictly bound to local host ports (`127.0.0.1`), and are not publicly routable.
* **Authentication:** Access to the workspace and monitoring tools is governed by Authelia via OIDC.
* **Workspace Isolation:** User workspaces run as isolated Docker containers spawned by JupyterHub, with strict CPU, RAM, and Shared Memory limits applied.


## Scope of Vulnerabilities

### In Scope

We are primarily interested in vulnerabilities that break the platform's isolation or authentication mechanisms, including:

* **Authentication Bypass:** Bypassing Authelia's OIDC SSO to access JupyterHub, Forgejo, or Grafana unauthenticated.
* **Container Escapes:** Techniques to break out of a spawned JupyterHub user container (Named Server) to access the underlying Debian VM host. *(Note: The JupyterHub core container intentionally mounts the Docker socket for orchestration, but user containers do not).*
* **Cross-Tenant Access:** Accessing another user's persistent data volume (`/home/jovyan`) or project containers without explicit RTC (Real-Time Collaboration) authorization.
* **Logout Chain Flaws:** Cross-Site Scripting (XSS), CSRF, or bypasses in the custom `logout-all.html` iframe/fetch logout chain that would leave a session active after a user attempts to log out.
* **Network Traversal:** Reaching the `ds-backend-net` or directly accessing PostgreSQL/Valkey from the external internet.


### Out of Scope

The following issues are generally considered out of scope:

* **Exposed `.example` files:** The `secrets/vault.yml.example` and `ansible/group_vars/all.yml.example` files contain placeholder values and dummy data by design. They are not real credentials.
* **Upstream Zero-Days:** Vulnerabilities in the underlying open-source software (e.g., Docker, Postgres, Caddy) unless our specific configuration or Ansible deployment methodology exposes them unnecessarily.
