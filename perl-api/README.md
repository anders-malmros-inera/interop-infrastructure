# Perl API for Service Catalog

This directory contains a simple OO-Perl implementation of the OpenAPI in `openapi/service-catalog-openapi.yaml`.

Build and run locally (example using docker-compose file in repo root named `docker-compose.perl-api.yml`):

```powershell
Set-Location 'c:\dev\workspace\interop-infrastructure'
docker-compose -f docker-compose.perl-api.yml up --build
```

The API will listen on port 5000. Example endpoints:
- GET /apis?logicalAddress={}&interoperabilitySpecificationId={}
- POST /apis
- GET /apis/{id}
- PUT /apis/{id}
- DELETE /apis/{id}
- GET /sync/apis

Environment variables used for DB connection:
- DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS
