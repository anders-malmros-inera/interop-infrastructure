[1. Overview](#sec-1-overview)

[2. Build and run with Docker](#sec-2-build-and-run-with-docker)

[3. docker-compose note](#sec-3-docker-compose-note)

[4. Endpoints](#sec-4-endpoints)


<a id="doc-java-api-spring-boot-for-service-catalog"></a>
# Java API (Spring Boot) for Service Catalog

<a id="sec-1-overview"></a>
## 1. Overview

This directory contains a minimal Spring Boot implementation of the Service Catalog API that connects to the existing Postgres database.

<a id="sec-2-build-and-run-with-docker"></a>
## 2. Build and run with Docker

Build and run with Docker (example):

```powershell
Set-Location 'c:\dev\workspace\interop-infrastructure\java-api'
docker build -t java-service-catalog:latest .
docker run --rm -p 8080:8080 -e DB_HOST=db -e DB_PORT=5432 -e DB_NAME=service_catalog -e DB_USER=svcuser -e DB_PASS=svcpass java-service-catalog:latest
```

<a id="sec-3-docker-compose-note"></a>
## 3. docker-compose note

Or use the top-level `docker-compose.dev.yml` which includes `db`, `api` (perl), `openapi` and you can add this service (I updated the compose to include it).

<a id="sec-4-endpoints"></a>
## 4. Endpoints

Endpoints mirror the OpenAPI minimal surface:
- GET /apis
- POST /apis
- GET /apis/{id}
- PUT /apis/{id}
- DELETE /apis/{id}
- GET /sync/apis (basic filter)
