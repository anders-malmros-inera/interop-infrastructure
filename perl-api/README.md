<a id="sec-1-perl-api"></a>
# 1. Perl API for Service Catalog

## 1.1. Index

- [1. Perl API for Service Catalog](#sec-1-perl-api)
- [1.1 Build and run locally](#sec-1-1-build-and-run-locally)
- [1.2 Example endpoints](#sec-1-2-example-endpoints)
- [1.3 Environment variables](#sec-1-3-environment-variables)

<a id="sec-1-1-build-and-run-locally"></a>
## 1.2. 1 Build and run locally

This directory contains a simple OO-Perl implementation of the OpenAPI in `openapi/service-catalog-openapi.yaml`.

Build and run locally (example using docker-compose file in repo root named `docker-compose.perl-api.yml`):

```powershell
Set-Location 'c:\dev\workspace\interop-infrastructure'
docker-compose -f docker-compose.perl-api.yml up --build
```

<a id="sec-1-2-example-endpoints"></a>
## 1.3. 2 Example endpoints

The API will listen on port 5000. Example endpoints:
- GET /apis?logicalAddress={}&interoperabilitySpecificationId={}
- POST /apis
- GET /apis/{id}
- PUT /apis/{id}
- DELETE /apis/{id}
- GET /sync/apis

<a id="sec-1-3-environment-variables"></a>
## 1.4. 3 Environment variables

Environment variables used for DB connection:
- DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS
