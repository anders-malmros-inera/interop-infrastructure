Hardening Kong
===============

Recommendations to secure Kong in production:

- Do not map the Admin port to host. Keep it on a private management network.
- Protect the Admin API with authentication and restrict access by IP or VPN.
- Enable TLS on the proxy ports and redirect HTTP->HTTPS.
- Enable rate-limiting, request-size and body rules per API to reduce abuse.
- Backup declarative configs (kong.yml) and store them encrypted in the registry/secret store.

For Kubernetes-based deployments consider Kong Ingress Controller and RBAC for the Admin interface.
