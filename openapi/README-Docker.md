# Index

- 1. <a id="sec-1-openapi-docker"></a>  [â†©](#sec-1-section)
- 2. <a id="sec-1-openapi-docker"></a>  [â†©](#sec-2-section)
- 3. <a id="sec-1-openapi-docker"></a>  [â†©](#sec-3-section)
- 4. <a id="sec-1-openapi-docker"></a>  [â†©](#sec-4-section)
- 5. Serve OpenAPI (service-catalog) with Docker  [â†©](#sec-5-serve-openapi-service-catalog-with-docker)

<a id="sec-1-section"></a>
# 1. <a id="sec-1-openapi-docker"></a>
<a id="sec-2-section"></a>
# 2. <a id="sec-1-openapi-docker"></a>
<a id="sec-3-section"></a>
# 3. <a id="sec-1-openapi-docker"></a>
<a id="sec-4-section"></a>
# 4. <a id="sec-1-openapi-docker"></a>
<a id="sec-5-serve-openapi-service-catalog-with-docker"></a>
# 5. Serve OpenAPI (service-catalog) with Docker

This folder contains the OpenAPI spec and a simple Docker setup to serve the static files using nginx.

Files:
- `service-catalog-api.html` — existing HTML view
- `service-catalog-openapi.yaml` — OpenAPI YAML
- `Dockerfile` — builds an nginx image serving the folder
- `docker-compose.yml` — convenience compose file (maps port 8080)

PowerShell: build and run with Docker CLI

```powershell
# 3. from this folder (openapi)
docker build -t interop-openapi:latest .
docker run --rm -p 8080:80 interop-openapi:latest
```

Or use docker-compose (recommended for quick runs):

```powershell
# 4. from this folder (openapi)
docker-compose up --build
```

Then open in your browser:

http://localhost:8080/service-catalog-api.html

Notes:
- The nginx container serves everything in this folder. If the HTML references the YAML with a relative path it will be able to fetch it without CORS issues.
- If you'd like a single-file HTML (no server required), consider `redoc-cli bundle service-catalog-openapi.yaml -o service-catalog-api.html`.
