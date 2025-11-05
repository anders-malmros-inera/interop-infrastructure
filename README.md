[1. Kong gateway — routes & usage](#sec-1-kong-gateway-routes-usage)

[2. Prerequisites](#sec-2-prerequisites)

[3. What the compose stack provides](#sec-3-what-the-compose-stack-provides)

[4. Port mappings (host -> container)](#sec-4-port-mappings-host-container)

[5. Quick start (PowerShell)](#sec-5-quick-start-powershell)

[6. Health & verification](#sec-6-health-verification)

[7. Database credentials (development)](#sec-7-database-credentials-development)

[8. Troubleshooting](#sec-8-troubleshooting)

[9. Component READMEs](#sec-9-component-readmes)

[10. Migrations & helper scripts](#sec-10-migrations-helper-scripts)

[11. Recent changes (short)](#sec-11-recent-changes-short)

[12. Next steps and suggestions](#sec-12-next-steps-and-suggestions)

[13. Component READMEs](#sec-13-component-readmes)

[14. Next steps and suggestions](#sec-14-next-steps-and-suggestions)

[15. Integration tests & recent fix](#sec-15-integration-tests-recent-fix)


<a id="doc-interop-infrastructure-local-development"></a>
# interop-infrastructure - local development

This repository contains a small local development stack for the Service Catalog / API interoperability examples used in this workspace.

Public access is routed through a single API gateway (Kong) in DB-less, declarative mode. Kong runs on the host and proxies requests to the internal services which are attached to either the `dmz` or `backend` Docker networks. With Kong in front, individual services are not required to expose host ports — Kong provides a single public entrypoint for HTTP/HTTPS and routes requests to the appropriate internal service.

This README explains how to build and run the services with Docker Compose, the ports used, and quick troubleshooting tips.

<a id="sec-1-kong-gateway-routes-usage"></a>
## 1. Kong gateway — routes & usage

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


<a id="sec-2-prerequisites"></a>
## 2. Prerequisites

- Docker Desktop (or Docker Engine) installed and running
- Docker Compose (v2) - available via the `docker compose` command
- On Windows, PowerShell is used in the examples below

<a id="sec-3-what-the-compose-stack-provides"></a>
## 3. What the compose stack provides

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

<a id="sec-4-port-mappings-host-container"></a>
## 4. Port mappings (host -> container)

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

<a id="sec-5-quick-start-powershell"></a>
## 5. Quick start (PowerShell)

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

<a id="sec-6-health-verification"></a>
## 6. Health & verification

Check containers:

```powershell
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

API health endpoints (when stack is up — use Kong as the public gateway):

- Perl API (via Kong): `http://localhost:8080/perl/_ping` -> {"ok":1,"now":"..."}
- Java API (via Kong): `http://localhost:8080/java/_ping` -> {"ok":1,"now":"..."}

Note: the services still listen on their internal container ports (Perl:5000, Java:8080) but they are not published to the host — use the Kong proxy paths above.

Notes:
- The Perl API service is available as the compose service `api`. To target the running container directly prefer using Compose commands such as `docker compose ps -q api` to obtain the container id or `docker compose exec api <cmd>` rather than relying on a fixed container name.
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

<a id="sec-7-database-credentials-development"></a>
## 7. Database credentials (development)

- DB name: `service_catalog`
- DB user: `svcuser`
- DB password: `svcpass`
- The APIs are configured in compose to connect to the service name `db` (host `db` inside the compose network).

If you need to connect from the host (psql), you can use the mapped host port (5432) and the same credentials.

<a id="sec-8-troubleshooting"></a>
## 8. Troubleshooting

- If build fails due to missing directories referenced by the compose file (for example `service-catalog` or `admin-runner`), either add those directories or remove/comment the related services in `docker-compose.yml`.
- To inspect logs:

```powershell
docker logs --since 0s interop-infrastructure-api-1 --tail 200
docker logs --since 0s interop-infrastructure-java-api-1 --tail 200
docker logs --since 0s interop-infrastructure-db-1 --tail 200
```

- If ports are already in use on the host, edit `docker-compose.yml` to remap host ports.

<a id="sec-9-component-readmes"></a>
## 9. Component READMEs

This repository contains a few services each with their own README. The admin GUI (`admin-web`) can list and render these READMEs in the right-hand pane.

Links to component READMEs in this repository:

- [admin-web README](./admin-web/README.md) - the admin/test-runner UI and developer notes.
- [perl-api README](./perl-api/README.md) - instructions for the Perl (Dancer2) implementation.
- [java-api README](./java-api/README.md) - notes for the Java (Spring Boot) implementation.
- [openapi README (Docker)](./openapi/README-Docker.md) - openapi static server and Docker notes.
- [perl-federation README](./perl-federation/README.md) - federation membership service (Perl/Dancer2) and OpenAPI docs.

If you add more components with README files at the top level, the admin GUI will automatically detect and list them.

<a id="sec-10-migrations-helper-scripts"></a>
## 10. Migrations & helper scripts

This repository includes an idempotent migration mechanism and a couple of small helper scripts to make local development and upgrades smoother.

- Migrations are stored under `service-catalog-db/migrations/` as plain `.sql` files. These are intended to be run against the running Postgres container to apply schema changes in a safe, additive way (use `CREATE TABLE IF NOT EXISTS` or `ALTER TABLE` statements).
- When the Postgres image initializes a fresh volume, files in `service-catalog-db/init.sql` are applied automatically by the official Postgres image. If your DB volume was created before you added or changed `init.sql`, the init script will not be re-run for that existing volume. Use the migration script below to apply changes to an existing database.

Helper scripts (in `scripts/`):

- `scripts/apply-db-migrations.ps1` — PowerShell helper that copies and applies all `.sql` files from `service-catalog-db/migrations/` to the running DB container (`interop-infrastructure-db-1`). Use this for existing volumes where `init.sql` didn't run. Example:

```powershell
cd C:\dev\workspace\interop-infrastructure
.\scripts\apply-db-migrations.ps1
```

- `scripts/reload-kong.ps1` — simple helper to restart the Kong container so the declarative `kong.yml` is reloaded. Use after editing `kong.yml`:

```powershell
cd C:\dev\workspace\interop-infrastructure
.\scripts\reload-kong.ps1
```

<a id="sec-11-recent-changes-short"></a>
## 11. Recent changes (short)

The stack has received a few small updates improving the test-runner and developer workflows. Key items:

- Federation membership service scaffold (`perl-federation`) added and documented with OpenAPI pages. The service is proxied through Kong (route `/federation`).
- The admin-web test-runner was made robust to host vs in-Docker execution and now probes candidate endpoints before running tests.
- An idempotent migration file was added for the `members` table: `service-catalog-db/migrations/0001_create_members.sql`.
- A convenience script to apply migrations to an existing DB volume was added: `scripts/apply-db-migrations.ps1`.
- The `federation` service no longer exposes a host port by default (it is backend-only and reachable via Kong). This keeps parity with other backend services — to test via host you can temporarily re-add the `ports` mapping in your local copy of `docker-compose.yml`.
- Admin-web exposes a health-check endpoint that verifies Kong routing and federation DB access: `GET /api/health-check` (proxied via Kong at `http://localhost:8080/api/health-check`).

If you rely on an existing DB volume and want the new members table applied automatically, run the PowerShell migration helper above or recreate the DB volume (caveat: recreating the volume removes existing data):

```powershell
docker compose -f docker-compose.yml down -v
docker compose -f docker-compose.yml up --build -d
```


<a id="sec-12-next-steps-and-suggestions"></a>
## 12. Next steps and suggestions

 - To inspect logs:

```powershell
docker logs --since 0s interop-infrastructure-api-1 --tail 200
docker logs --since 0s interop-infrastructure-java-api-1 --tail 200
docker logs --since 0s interop-infrastructure-db-1 --tail 200
```

 - If ports are already in use on the host, edit `docker-compose.yml` to remap host ports.

<a id="sec-13-component-readmes"></a>
## 13. Component READMEs

This repository contains a few services each with their own README. The admin GUI (`admin-web`) can list and render these READMEs in the right-hand pane.

Links to component READMEs in this repository:

- [admin-web README](./admin-web/README.md) — the admin/test-runner UI and developer notes.
- [perl-api README](./perl-api/README.md) — instructions for the Perl (Dancer2) implementation.
- [java-api README](./java-api/README.md) — notes for the Java (Spring Boot) implementation.
- [openapi README (Docker)](./openapi/README-Docker.md) — openapi static server and Docker notes.

If you add more components with README files at the top level, the admin GUI will automatically detect and list them.

<a id="sec-14-next-steps-and-suggestions"></a>
## 14. Next steps and suggestions

 - Add `healthcheck` entries for the `api` and `java-api` services for stronger depends_on semantics.
 - Remove orphan containers if you don't need them:

```powershell
docker compose -f docker-compose.yml down --remove-orphans
```

 - Add a README or small guide inside `java-api/` and `perl-api/` describing how to run and develop inside the service (IDE tips, mvn/p5 commands).
 - Consider adding a migration tool (Flyway/Liquibase) for the Java app and a similar migration approach for the Perl app to manage schema changes.

Security note — Kong admin API

- By default this compose setup does not expose the Kong Admin API on the host. Avoid publishing the admin port (`8001`) on shared machines. If you need to debug Kong locally temporarily, publish the port only for the duration of your debug session and remove it afterwards, or restrict access via a firewall or SSH tunnel. Do NOT leave the admin API exposed in multi-user or CI environments.

If you want, I can add healthchecks for the two APIs in `docker-compose.yml` and remove orphan containers — tell me which you'd like me to do next.

<a id="sec-15-integration-tests-recent-fix"></a>
## 15. Integration tests & recent fix

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
