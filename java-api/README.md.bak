# Java API (Spring Boot) for Service Catalog

## 1 Overview

This directory contains a minimal Spring Boot implementation of the Service Catalog API that connects to the existing Postgres database.

## 2 Build and run with Docker

Build and run with Docker (example):

```powershell
Set-Location 'c:\dev\workspace\interop-infrastructure\java-api'
docker build -t java-service-catalog:latest .
docker run --rm -p 8080:8080 -e DB_HOST=db -e DB_PORT=5432 -e DB_NAME=service_catalog -e DB_USER=svcuser -e DB_PASS=svcpass java-service-catalog:latest
```

## 3 docker-compose note

Or use the top-level `docker-compose.dev.yml` which includes `db`, `api` (perl), `openapi` and you can add this service (I updated the compose to include it).

## 4 Endpoints

Endpoints mirror the OpenAPI minimal surface:
- GET /apis
- POST /apis
- GET /apis/{id}
- PUT /apis/{id}
- DELETE /apis/{id}
- GET /sync/apis (basic filter)
