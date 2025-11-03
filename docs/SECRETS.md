Secrets management
==================

Do not store secrets (passwords, tokens, private keys) in git. Use a secrets manager such as HashiCorp Vault or your cloud provider's secret manager.

Quick steps:
- Add a `.env.example` (provided in repo) and keep `.env` out of git via `.gitignore`.
- CI should read secrets from the environment or a secrets manager (GitHub Actions secrets, or Vault with OIDC).
- For Kubernetes, use Kubernetes Secrets or a Vault injector (e.g. vault-agent injector / external-secrets).

Rotation and access:
- Define an access policy and rotate credentials on a schedule.
- Limit who can read production secrets and enable audit logging.

Recommendations:
- Replace plaintext credentials in `docker-compose.yml` with references to environment variables.
- Add a `scripts/rotate-secrets.sh` placeholder to demonstrate rotation workflow.
