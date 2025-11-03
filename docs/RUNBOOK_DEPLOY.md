Deployment runbook (basic)
=========================

Purpose: quick steps to deploy the stack to a staging environment. This is a developer-facing runbook and should be expanded for production.

1. Build images locally (or use CI):
   - `docker build -f admin-web/Dockerfile -t <registry>/interop-admin-web:TAG ./`
2. Push images to registry and update `helm/values.yaml` with the image tags.
3. Deploy Helm chart to the cluster:
   - `helm upgrade --install interop ./helm -n staging --create-namespace`
4. Run database migrations (see `migrations/` directory).
5. Run smoke tests: use `kubectl exec` or port-forwarding to run `perl t/01-smoke.t` against staging.

If a deploy fails, follow the rollback section:
- `helm rollback interop <revision>`
- If DB migration failed and requires rollback, follow DB restore runbook.
