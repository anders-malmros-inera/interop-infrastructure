# interop-infrastructure - local development

This repository contains a small local development stack for the Service Catalog / API interoperability examples used in this workspace.

Public access is routed through a single API gateway (Kong) in DB-less, declarative mode. Kong runs on the host and proxies requests to the internal services which are attached to either the `dmz` or `backend` Docker networks. With Kong in front, individual services are not required to expose host ports — Kong provides a single public entrypoint for HTTP/HTTPS and routes requests to the appropriate internal service.

This README explains how to build and run the services with Docker Compose, the ports used, and quick troubleshooting tips.

## Kong gateway — routes & usage

When the compose stack runs with Kong enabled the public entrypoint is Kong on the host. By default the compose in this repo publishes Kong's proxy on host port 8080 (HTTP) and 8443 (HTTPS), and the Kong Admin API on 8001 (optional).

Common Kong routes configured by the stack (defaults):

- http://localhost:8080/admin  -> admin-web UI and static assets
- http://localhost:8080/api    -> admin-web API endpoints (e.g. /api/run-tests)
- http://localhost:8080/readme -> admin-web README renderer (use /readme?container=<id>)
- http://localhost:8080/openapi -> static OpenAPI UI
- http://localhost:8080/perl    -> Perl API (proxied upstream at container:5000)
- http://localhost:8080/java    -> Java API (proxied upstream at container:8080)

Notes:

- The admin UI issues client-side requests to relative paths such as `/api/run-tests` and `/readme`. With Kong configured to forward `/api` and `/readme` to the admin-web service (without stripping the prefix) the UI works unchanged and the browser calls are correctly proxied.
- Kong is running in DB-less, declarative mode and reads `kong.yml` from the repository root; edit that file and restart the Kong container to change routes.
- Kong Admin API is published by the compose for convenience (`http://localhost:8001`) — consider removing the published admin port on shared machines.

Running tests (via Kong) and retrieving JUnit

 - Run the admin test-runner through Kong (returns JSON summary):

```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/admin/api/run-tests' -UseBasicParsing
```

(This calls the test-runner via Kong. If you previously exposed `admin-web` directly you can still call `http://localhost:8082/api/run-tests` when that host port is mapped.)

 - Run and write JUnit XML to the admin-web container (and return summary):

```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/api/run-tests?junit=1' -UseBasicParsing
```

 - Copy the JUnit file from the running admin-web container to the repo root:

```powershell
$cid = docker compose -f docker-compose.yml ps -q admin-web
docker cp $cid:/workspace/admin-web/test-results.xml .\test-results.xml
```

Notes:

 - The test-runner writes JUnit to `/workspace/admin-web/test-results.xml` inside the container when `?junit=1` is used. Copy it to host for CI consumption.
 - If the UI's Run Tests button still fails in the browser, open the developer console and look for failed fetches to `/api` or `/readme` — Kong should forward those intact to the admin-web service.


## Prerequisites

- Docker Desktop (or Docker Engine) installed and running
- Docker Compose (v2) - available via the `docker compose` command
- On Windows, PowerShell is used in the examples below

## What the compose stack provides

The top-level `docker-compose.yml` (in this folder) starts the following services:

- `db` - Postgres initialized with the `api_instances` table and one sample row (image built from `service-catalog-db/`).
- `api` - Perl implementation of the service-catalog API (Dancer2) listening on container port 5000.
  - Note: this service uses a fixed container name `perl-api-1` in the compose file for easier targeting in local dev.
- `java-api` - Java (Spring Boot) implementation of the same API listening on container port 8080.
- `openapi` - nginx-based static server serving the OpenAPI HTML UI on container port 80.
<!-- Keycloak is intentionally not included in this compose file. If you need an auth server for testing, run it separately and configure the gateway accordingly. -->

Notes:
- Both the Perl and Java APIs are configured to use the same Postgres service `db` (service name `db` inside the compose network). There used to be a second Postgres entry in the file; it has been removed to avoid confusion.
- The `openapi` service is DMZ-only and served through Kong at `/openapi` (no direct host port is published by the top-level compose).
 
Note: older convenience/dev compose files (for example `docker-compose.dev.yml` and `docker-compose.perl-api.yml`) previously exposed service ports for direct host access. These files have been updated to remove `ports:` mappings so services are only reachable via Kong. If you intentionally need direct host access for development, you can re-add `ports:` to a local copy of those files, but prefer the top-level compose with Kong for security.

## Port mappings (host -> container)

When running with Kong as the public gateway (recommended):

- 8080 -> Kong proxy (HTTP)
- 8443 -> Kong proxy (HTTPS) — not configured with certs by default
- 8001 -> Kong Admin API (optional)

Container/internal ports (service-to-service):

- 5000 -> Perl API (container)
- 8080 -> Java API (container)
- 80   -> openapi static UI (container)
- 5432 -> Postgres (DB used by the APIs)

Note: individual services are attached to `dmz` or `backend` networks and are not required to expose host ports when Kong is used. If you prefer direct host access for a service, edit `docker-compose.yml` to map the host port explicitly.

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

API health endpoints (when stack is up — use Kong as the public gateway):

- Perl API (via Kong): `http://localhost:8080/perl/_ping` -> {"ok":1,"now":"..."}
- Java API (via Kong): `http://localhost:8080/java/_ping` -> {"ok":1,"now":"..."}

Note: the services still listen on their internal container ports (Perl:5000, Java:8080) but they are not published to the host — use the Kong proxy paths above.

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

API listing example (use Kong proxy paths):

```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/perl/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1' -UseBasicParsing
Invoke-RestMethod -Uri 'http://localhost:8080/java/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1' -UseBasicParsing
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

- [admin-web README](./admin-web/README.md) - the admin/test-runner UI and developer notes.
- [perl-api README](./perl-api/README.md) - instructions for the Perl (Dancer2) implementation.
- [java-api README](./java-api/README.md) - notes for the Java (Spring Boot) implementation.
- [openapi README (Docker)](./openapi/README-Docker.md) - openapi static server and Docker notes.

If you add more components with README files at the top level, the admin GUI will automatically detect and list them.

## Next steps and suggestions

- Add healthcheck entries for the `api` and `java-api` services for stronger depends_on semantics.
- Remove orphan containers if you don't need them:

```powershell
docker compose -f docker-compose.yml down --remove-orphans
```

- Add a README or small guide inside `java-api/` and `perl-api/` describing how to run and develop inside the service (IDE tips, mvn/p5 commands).
- Consider adding a migration tool (Flyway/Liquibase) for the Java app and a similar migration approach for the Perl app to manage schema changes.

If you want, I can add healthchecks for the two APIs in `docker-compose.yml` and remove orphan containers - tell me which you'd like me to do next.

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

```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/admin/api/run-tests' -UseBasicParsing
```

(This calls the test-runner via Kong. If you expose the admin-web host port directly you can also call `http://localhost:8082/api/run-tests`.)

Notes about create responses
- The Perl API returns the created id as JSON: `{ "id": "..." }`.
- The Java API returns the created id as plain text. The test-runner is tolerant of both formats.

Status
- After the fix the admin-web test-runner shows successful CRUD sequences for both Perl and Java (POST -> GET -> PUT -> GET -> DELETE -> GET).

Suggested follow-ups

- Add request validation in the Perl model to return clearer 4xx responses for missing required fields.
- Standardize the create-response format (either always JSON with `{ id: ... }` or always plain text) to simplify clients and tests.
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
<!-- Keycloak is not included in this compose by default. Run an external auth server if you need authentication testing. -->

Notes:
- Both the Perl and Java APIs are configured to use the same Postgres service `db` (DB host `db` inside the compose network). There used to be a second Postgres entry in the file; it has been removed to avoid confusion.
The `openapi` service is DMZ-only and served via Kong at `http://localhost:8080/openapi` (no direct host port is published by the top-level compose).

## Port mappings (host -> container)

 - 5000 -> Perl API (http)
 - 8080 -> Java API (http)
 - (no direct host port) -> OpenAPI UI (nginx); use Kong `/openapi`
 - 5432 -> Postgres (DB used by the APIs)
 - (If you run an external auth server, map its host port as you prefer.)

## Component diagram (services & ports)

Below is a small component diagram that shows the main services in this repository and the ports used for host and container communication.

If your viewer does not render Mermaid diagrams, a pre-rendered SVG is included in the repo and displayed here:

![Component diagram](/admin/diagram.svg)

Notes:

- Host-exposed ports are shown as hostPort:containerPort. When using Kong the public mapping is `8080 -> Kong (proxy)` which forwards to the internal service ports (for example Kong forwards `/admin` to `admin-web:3000`).
- Container-to-container communication uses Docker service names and internal container ports (e.g., `admin-web` talks to `api` at `http://api:5000` inside the compose network).
<!-- Keycloak is not included in this compose by default. If you run an external auth server, configure its host port per your environment. -->


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

API health endpoints (use Kong proxy paths):

- Perl API (via Kong): `http://localhost:8080/perl/_ping` -> {"ok":1,"now":"..."}
- Java API (via Kong): `http://localhost:8080/java/_ping` -> {"ok":1,"now":"..."}

Notes:
- The services still listen on their internal container ports (Perl:5000, Java:8080) but they are not published to the host — use the Kong proxy paths above.

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

API listing example (use Kong proxy paths):

```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/perl/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1' -UseBasicParsing
Invoke-RestMethod -Uri 'http://localhost:8080/java/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1' -UseBasicParsing
```

## Database credentials (development)

- DB name: `service_catalog`
- DB user: `svcuser`
- DB password: `svcpass`
- The APIs are configured in compose to connect to the service name `db` (host `db` inside the compose network).

If you need to connect from the host (psql) for debugging, either publish the DB port in a local compose copy or exec into the container:

```powershell
docker compose -f docker-compose.yml exec db psql -U svcuser -d service_catalog
```

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
<!-- Keycloak dev server is optional and not included in this compose. Run an external auth server if required. -->

Notes:
- Both the Perl and Java APIs are configured to use the same Postgres service `db` (DB host `db` inside the compose network). There used to be a second Postgres entry in the file; it has been removed to avoid confusion.
- The `openapi` service is DMZ-only and served via Kong at `/openapi` (no direct host port is published by the top-level compose).

## Port mappings (host -> container)

When running with Kong as the public gateway (recommended):

- 8080 -> Kong proxy (HTTP)
- 8443 -> Kong proxy (HTTPS) — not configured with certs by default
- 8001 -> Kong Admin API (optional)

Container/internal ports (service-to-service):

- 5000 -> Perl API (container)
- 8080 -> Java API (container)
- 80   -> openapi static UI (container)
- 5432 -> Postgres (DB used by the APIs)

Note: individual services are attached to `dmz` or `backend` networks and are not required to expose host ports when Kong is used. If you prefer direct host access for a service, re-add `ports:` mappings to a local copy of a compose file for short-lived debugging.

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

API health endpoints (use Kong proxy paths):

- Perl API (via Kong): `http://localhost:8080/perl/_ping` -> {"ok":1,"now":"..."}
- Java API (via Kong): `http://localhost:8080/java/_ping` -> {"ok":1,"now":"..."}

Notes:
- The services still listen on their internal container ports (Perl:5000, Java:8080) but they are not published to the host — use the Kong proxy paths above.

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

API listing example (use Kong proxy paths):

```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/perl/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1' -UseBasicParsing
Invoke-RestMethod -Uri 'http://localhost:8080/java/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1' -UseBasicParsing
```

## Database credentials (development)

- DB name: `service_catalog`
- DB user: `svcuser`
- DB password: `svcpass`
- The APIs are configured in compose to connect to the service name `db` (host `db` inside the compose network).

If you need to connect from the host (psql) for debugging, either publish the DB port in a local compose copy or exec into the container:

```powershell
docker compose -f docker-compose.yml exec db psql -U svcuser -d service_catalog
```

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

Links to component README
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

```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/admin/api/run-tests' -UseBasicParsing
```

(Calls the test-runner via Kong; direct access to `http://localhost:8082/api/run-tests` works only if that host port is mapped in `docker-compose.yml`.)

Notes about create responses
- The Perl API returns the created id as JSON: `{ "id": "..." }`.
- The Java API returns the created id as plain text. The test-runner is tolerant of both formats.

Status
- After the fix the admin-web test-runner shows successful CRUD sequences for both Perl and Java (POST → GET → PUT → GET → DELETE → GET).

Suggested follow-ups
- Add request validation in the Perl model to return clearer 4xx responses for missing required fields.
- Standardize the create-response format (either always JSON with `{ id: ... }` or always plain text) to simplify clients and tests.
