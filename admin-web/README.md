# interop-infrastructure — local development

This repository contains a small local development stack for the Service Catalog / API interoperability examples used in this workspace.

This README explains how to build and run the services with Docker Compose, the ports used, and quick troubleshooting tips.

## Prerequisites

- Docker Desktop (or Docker Engine) installed and running
- Docker Compose (v2) — available via the `docker compose` command
- On Windows, PowerShell is used in the examples below

## What the compose stack provides

The top-level `docker-compose.yml` (in this folder) starts the following services:

- `db` — Postgres initialized with the `api_instances` table and one sample row (image built from `service-catalog-db/`).
- `api` — Perl implementation of the service-catalog API (Dancer2) listening on container port 5000.
    - Note: this service uses a fixed container name `perl-api-1` in the compose file for easier targeting in local dev.
- `java-api` — Java (Spring Boot) implementation of the same API listening on container port 8080.
- `openapi` — nginx-based static server serving the OpenAPI HTML UI on container port 80.
 - `openapi` — nginx-based static server serving the OpenAPI HTML UI on container port 80.
 - `keycloak` — (optional) Keycloak is not included in this compose by default. Run Keycloak separately if required for authentication testing.

Notes:
- Both the Perl and Java APIs are configured to use the same Postgres service `db` (DB host `db` inside the compose network). There used to be a second Postgres entry in the file; it has been removed to avoid confusion.
- The `openapi` service is published on host port `8081` (container `80`) to avoid collisions with the Java API on host port `8080`.

## Port mappings (host -> container)

 - 5000 -> Perl API (http)
 - 8080 -> Java API (http)
 - 8081 -> OpenAPI UI (nginx)
 - 5432 -> Postgres (DB used by the APIs)
 - 8180 -> Keycloak (if you run Keycloak separately and expose it on this host port)

## Quick start (PowerShell)

From the repository root:

```powershell
cd 'C:\dev\workspace\interop-infrastructure'
docker compose -f docker-compose.yml up --build -d
```

To stop and remove the stack:

```powershell
docker compose -f docker-compose.yml down
```

If you have old/renamed services left from a previous compose file, remove orphans when bringing the stack down:

```powershell
docker compose -f docker-compose.yml down --remove-orphans
```

## Health & verification

Check containers:

```powershell
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

API health endpoints (when stack is up):

 - Perl API (health): `http://localhost:5000/_ping` -> {"ok":1,"now":"..."}
 - Java API (health): `http://localhost:8080/_ping` -> {"ok":1,"now":"..."}

Notes:
- The Perl API container is named `perl-api-1` (see `container_name` in `docker-compose.yml`). Use that name when you want to target the container directly.
- The Java API now exposes `/_ping` as well (added to the codebase) so both services have a consistent health endpoint.

Recreate a single service without touching the rest of the stack (useful after code changes):

```powershell
docker compose -f docker-compose.yml up -d --no-deps --build api
docker compose -f docker-compose.yml up -d --no-deps --build java-api
```

If you only need to remove a single orphan container (instead of stopping the whole stack) use:

```powershell
docker stop <container-name>
docker rm <container-name>
```

API listing example (returns entries from the shared `db`):

```powershell
Invoke-RestMethod -Uri 'http://localhost:5000/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1' -UseBasicParsing
Invoke-RestMethod -Uri 'http://localhost:8080/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1' -UseBasicParsing
```

## Database credentials (development)

 - DB name: `service_catalog`
 - DB user: `svcuser`
 - DB password: `svcpass`
 - The APIs are configured in compose to connect to the service name `db` (host `db` inside the compose network).

If you need to connect from the host (psql), you can use the mapped host port (5432) and the same credentials.

## Troubleshooting

 - If build fails due to missing directories referenced by the compose file (for example `service-catalog` or `admin-runner`), either add those directories or remove/comment the related services in `docker-compose.yml`.
 - To inspect logs:

```powershell
docker logs --since 0s interop-infrastructure-api-1 --tail 200
docker logs --since 0s interop-infrastructure-java-api-1 --tail 200
docker logs --since 0s interop-infrastructure-db-1 --tail 200
```

 - If ports are already in use on the host, edit `docker-compose.yml` to remap host ports.

## Component READMEs

This repository contains a few services each with their own README. The admin GUI (`admin-web`) can list and render these READMEs in the right-hand pane.

Links to component READMEs in this repository:

- [admin-web README](./admin-web/README.md) — the admin/test-runner UI and developer notes.
- [perl-api README](./perl-api/README.md) — instructions for the Perl (Dancer2) implementation.
- [java-api README](./java-api/README.md) — notes for the Java (Spring Boot) implementation.
- [openapi README (Docker)](./openapi/README-Docker.md) — openapi static server and Docker notes.

If you add more components with README files at the top level, the admin GUI will automatically detect and list them.

## Next steps and suggestions

 - Add `healthcheck` entries for the `api` and `java-api` services for stronger depends_on semantics.
 - Remove orphan containers if you don't need them:

```powershell
docker compose -f docker-compose.yml down --remove-orphans
```

 - Add a README or small guide inside `java-api/` and `perl-api/` describing how to run and develop inside the service (IDE tips, mvn/p5 commands).
 - Consider adding a migration tool (Flyway/Liquibase) for the Java app and a similar migration approach for the Perl app to manage schema changes.

If you want, I can add healthchecks for the two APIs in `docker-compose.yml` and remove orphan containers — tell me which you'd like me to do next.

## Integration tests & recent fix

While expanding the `admin-web` integration test-runner to perform full CRUD tests, a failure was observed when creating (POST) entries against the Perl API: the DB error showed NULL values for required columns (for example `logical_address`).

Root cause
- The Perl Dancer2 POST/PUT handlers were using `body_parameters->as_hashref`, which did not reliably decode nested JSON objects in the request body (forms vs JSON). This caused nested fields such as `organization` and `accessModel` to be lost, resulting in NULL columns when inserting into Postgres.

Fix applied
- The Perl handlers for `POST /apis` and `PUT /apis/:id` now explicitly decode the raw JSON request body using `JSON::MaybeXS::decode_json` before passing the payload to the model. This preserves nested objects and prevents NULLs for required columns.

How to rebuild and run the integration tests
- Rebuild the Perl API image (so the code changes take effect):

```powershell
cd 'C:\dev\workspace\interop-infrastructure'
docker compose -f docker-compose.yml build api
```

- Run the admin-web test-runner (this runs inside the compose network and exercises both services):

```powershell
docker compose -f docker-compose.yml run --rm admin-web node test-runner.js
```

- Alternatively, if the stack is running you can call the admin-web HTTP endpoint which runs the same suite and returns JSON:

```
http://localhost:8082/api/run-tests
```

Notes about create responses
- The Perl API returns the created id as JSON: `{ "id": "..." }`.
- The Java API returns the created id as plain text. The test-runner is tolerant of both formats.

Status
- After the fix the admin-web test-runner shows successful CRUD sequences for both Perl and Java (POST → GET → PUT → GET → DELETE → GET).

Suggested follow-ups
- Add request validation in the Perl model to return clearer 4xx responses for missing required fields.
- Standardize the create-response format (either always JSON with `{ id: ... }` or always plain text) to simplify clients and tests.
# interop-infrastructure (summary)

This admin web ships a small test-runner and helper UI for local development of the interop stack.

For full repository documentation, see the top-level README in the repository root. This page is a short summary intended to be displayed inside the admin GUI.

Quick notes:
- Run the full stack with `docker compose -f docker-compose.yml up --build -d` from the repository root.
- Run the integration tests using the admin UI (Run tests button) or call `GET /api/run-tests`.

If you need the complete README content displayed here, tell me and I can copy the full repo README into this file (it will be included in the admin-web image on rebuild).
