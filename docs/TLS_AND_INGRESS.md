TLS and ingress
===============

This project uses Kong as the API gateway. For production you should:

- Terminate TLS at the ingress (Kong or external load balancer).
- Use an automated certificate manager (cert-manager on Kubernetes or your cloud provider's managed certificates).
- Ensure HSTS is enabled and weak TLS cipher suites are disabled.
- Do not expose the Kong Admin API to the public internet. Restrict it to an admin network or use a bastion.

If you migrate to Kubernetes:

- Install `cert-manager` and issue certificates via ACME/Let's Encrypt or your CA.
- Configure Ingress with TLS and redirect HTTP -> HTTPS.
