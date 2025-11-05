# Index

- 1. Prerequisites  [â†©](#sec-1-prerequisites)
- 2. What the compose stack provides  [â†©](#sec-2-what-the-compose-stack-provides)
- 3. Port mappings (host -> container)  [â†©](#sec-3-port-mappings-host-container)
- 4. Quick start (PowerShell)  [â†©](#sec-4-quick-start-powershell)
- 5. Health & verification  [â†©](#sec-5-health-verification)
- 6. Database credentials (development)  [â†©](#sec-6-database-credentials-development)
- 7. Troubleshooting  [â†©](#sec-7-troubleshooting)
- 8. Component READMEs  [â†©](#sec-8-component-readmes)
- 9. Admin-web additional notes  [â†©](#sec-9-admin-web-additional-notes)
- 10. Next steps and suggestions  [â†©](#sec-10-next-steps-and-suggestions)
- 11. Integration tests & recent fix  [â†©](#sec-11-integration-tests-recent-fix)
- 12. # 11.1. Root cause  [â†©](#sec-12-11-1-root-cause)
- 13. # 11.2. Fix applied  [â†©](#sec-13-11-2-fix-applied)
- 14. # 11.3. How to rebuild and run the integration tests  [â†©](#sec-14-11-3-how-to-rebuild-and-run-the-integration-tests)
- 15. # 11.4. Notes about create responses  [â†©](#sec-15-11-4-notes-about-create-responses)
- 16. # 11.5. Status  [â†©](#sec-16-11-5-status)
- 17. # 11.6. Suggested follow-ups  [â†©](#sec-17-11-6-suggested-follow-ups)

<a id="doc-interop-infrastructure-local-development"></a>
# Interop-infrastructure — local development

This repository contains a small local development stack for the Service Catalog / API interoperability examples used in this workspace.

This README explains how to build and run the services with Docker Compose, the ports used, and quick troubleshooting tips.

<a id="sec-1-prerequisites"></a>
## 1. Prerequisites

- Docker Desktop (or Docker Engine) installed and running
- Docker Compose (v2) — available via the `docker compose` command
- On Windows, PowerShell is used in the examples below

<a id="sec-2-what-the-compose-stack-provides"></a>
## 2. What the compose stack provides

The top-level `docker-compose.yml` (in this folder) starts the following services:

- `db` — Postgres initialized with the `api_instances` table and one sample row (image built from `service-catalog-db/`).
- `api` — Perl implementation of the service-catalog API (Dancer2) listening on container port 5000.
    - Note: this service uses a fixed container name `perl-api-1` in the compose file for easier targeting in local dev.
- `java-api` — Java (Spring Boot) implementation of the same API listening on container port 8080.
- `openapi` — nginx-based static server serving the OpenAPI HTML UI on container port 80.

Notes:
- Both the Perl and Java APIs are configured to use the same Postgres service `db` (DB host `db` inside the compose network). There used to be a second Postgres entry in the file; it has been removed to avoid confusion.
The `openapi` service is DMZ-only and served via Kong at `/openapi` (no direct host port is published by the top-level compose).

<a id="sec-3-port-mappings-host-container"></a>
## 3. Port mappings (host -> container)

When running with Kong as the public gateway (recommended):

- 8080 -> Kong proxy (HTTP)
- 8443 -> Kong proxy (HTTPS) — not configured with certs by default
- 8001 -> Kong Admin API (optional)

Container/internal ports:

- 5000 -> Perl API (container)
- 8080 -> Java API (container)
- 80   -> openapi static UI (container)
- 5432 -> Postgres (DB used by the APIs)

<a id="sec-4-quick-start-powershell"></a>
## 4. Quick start (PowerShell)

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

<a id="sec-5-health-verification"></a>
## 5. Health & verification

Check containers:

```powershell
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

API health endpoints (use Kong proxy paths):

- Perl API (via Kong): `http://localhost:8080/perl/_ping` -> {"ok":1,"now":"..."}
- Java API (via Kong): `http://localhost:8080/java/_ping` -> {"ok":1,"now":"..."}
- Federation (via Kong): `http://localhost:8080/federation/_ping` -> {"ok":1,"now":"..."}

Notes:
- The Perl API container is named `perl-api-1` (see `container_name` in `docker-compose.yml`). Use that name when you want to target the container directly.
- The Java API now exposes `/_ping` as well (added to the codebase) so both services have a consistent health endpoint.

<a id="sec-6-database-credentials-development"></a>
## 6. Database credentials (development)

- DB name: `service_catalog`
- DB user: `svcuser`
- DB password: `svcpass`
- The APIs are configured in compose to connect to the service name `db` (host `db` inside the compose network).

If you need to connect from the host (psql), you can use the mapped host port (5432) and the same credentials.

<a id="sec-7-troubleshooting"></a>
## 7. Troubleshooting

- If build fails due to missing directories referenced by the compose file (for example `service-catalog` or `admin-runner`), either add those directories or remove/comment the related services in `docker-compose.yml`.
- To inspect logs:

```powershell
docker logs --since 0s interop-infrastructure-api-1 --tail 200
docker logs --since 0s interop-infrastructure-java-api-1 --tail 200
docker logs --since 0s interop-infrastructure-db-1 --tail 200
```

- If ports are already in use on the host, edit `docker-compose.yml` to remap host ports.

<a id="sec-8-component-readmes"></a>
## 8. Component READMEs

This repository contains a few services each with their own README. The admin GUI (`admin-web`) can list and render these READMEs in the right-hand pane.

Links to component READMEs in this repository:

- [admin-web README](./admin-web/README.md) — the admin/test-runner UI and developer notes.
- [perl-api README](./perl-api/README.md) — instructions for the Perl (Dancer2) implementation.
- [java-api README](./java-api/README.md) — notes for the Java (Spring Boot) implementation.
- [openapi README (Docker)](./openapi/README-Docker.md) — openapi static server and Docker notes.

If you add more components with README files at the top level, the admin GUI will automatically detect and list them.

<a id="sec-9-admin-web-additional-notes"></a>
## 9. Admin-web additional notes

- New health-check endpoint: `GET /api/health-check` — verifies that Kong has the `/federation` route configured and that the federation service responds to `/_ping` and `/members`. When running the stack with Kong as gateway this is reachable at `http://localhost:8080/api/health-check`.

- Running tests and JUnit output: the admin-web `GET /api/run-tests` endpoint runs the integration test-suite (same as the UI Run Tests) and can produce a JUnit XML when `?junit=1` is passed. The test-runner also saves a JSON summary of results inside the container; when executed via the public Kong proxy the saved JSON can be copied from the admin-web container if needed. Example flow to write and fetch JUnit from the running admin-web container:

```powershell
# 3. run tests and ask for junit
Invoke-RestMethod -Uri 'http://localhost:8080/api/run-tests?junit=1' -UseBasicParsing

# 4. copy junit to host
$cid = docker compose -f docker-compose.yml ps -q admin-web
docker cp $cid:/workspace/admin-web/test-results.xml .\test-results.xml
```

Note: the admin-web also exposes `/api/readmes` and `/readme?container=<id>` which are used by the UI to render component README pages inside the app.

<a id="sec-10-next-steps-and-suggestions"></a>
## 10. Next steps and suggestions

- Add `healthcheck` entries for the `api` and `java-api` services for stronger depends_on semantics.
- Remove orphan containers if you don't need them:

```powershell
docker compose -f docker-compose.yml down --remove-orphans
```

- Add a README or small guide inside `java-api/` and `perl-api/` describing how to run and develop inside the service (IDE tips, mvn/p5 commands).
- Consider adding a migration tool (Flyway/Liquibase) for the Java app and a similar migration approach for the Perl app to manage schema changes.

If you want, I can add healthchecks for the two APIs in `docker-compose.yml` and remove orphan containers — tell me which you'd like me to do next.

<a id="sec-11-integration-tests-recent-fix"></a>
## 11. Integration tests & recent fix

While expanding the `admin-web` integration test-runner to perform full CRUD tests, a failure was observed when creating (POST) entries against the Perl API: the DB error showed NULL values for required columns (for example `logical_address`).

<a id="sec-12-11-1-root-cause"></a>
## 12. # 11.1. Root cause
- The Perl Dancer2 POST/PUT handlers were using `body_parameters->as_hashref`, which did not reliably decode nested JSON objects in the request body (forms vs JSON). This caused nested fields such as `organization` and `accessModel` to be lost, resulting in NULL columns when inserting into Postgres.

<a id="sec-13-11-2-fix-applied"></a>
## 13. # 11.2. Fix applied
- The Perl handlers for `POST /apis` and `PUT /apis/:id` now explicitly decode the raw JSON request body using `JSON::MaybeXS::decode_json` before passing the payload to the model. This preserves nested objects and prevents NULLs for required columns.

<a id="sec-14-11-3-how-to-rebuild-and-run-the-integration-tests"></a>
## 14. # 11.3. How to rebuild and run the integration tests
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

<a id="sec-15-11-4-notes-about-create-responses"></a>
## 15. # 11.4. Notes about create responses
- The Perl API returns the created id as JSON: `{ "id": "..." }`.
- The Java API returns the created id as plain text. The test-runner is tolerant of both formats.

<a id="sec-16-11-5-status"></a>
## 16. # 11.5. Status
- After the fix the admin-web test-runner shows successful CRUD sequences for both Perl and Java (POST → GET → PUT → GET → DELETE → GET).

<a id="sec-17-11-6-suggested-follow-ups"></a>
## 17. # 11.6. Suggested follow-ups
- Add request validation in the Perl model to return clearer 4xx responses for missing required fields.
- Standardize the create-response format (either always JSON with `{ id: ... }` or always plain text) to simplify clients and tests.
- ## 1.12 Summary

This admin web ships a small test-runner and helper UI for local development of the interop stack.

For full repository documentation, see the top-level README in the repository root. This page is a short summary intended to be displayed inside the admin GUI.

Quick notes:
- Run the full stack with `docker compose -f docker-compose.yml up --build -d` from the repository root.
- Run the integration tests using the admin UI (Run tests button) or call `GET /api/run-tests`.

If you need the complete README content displayed here, tell me and I can copy the full repo README into this file (it will be included in the admin-web image on rebuild).
