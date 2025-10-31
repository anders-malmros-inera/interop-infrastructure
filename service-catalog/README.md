Service Catalog - scaffold

This is a starter scaffold for the Service Catalog microservice.

Run locally (dev):

- Build:
  mvn clean package

- Run (jar):
  java -jar target/service-catalog-0.0.1-SNAPSHOT.jar

Docker Compose (Keycloak + Postgres + app):

  docker-compose up --build

Notes:
- Security: the app is configured as an OAuth2 resource server (JWT) and expects Keycloak at http://localhost:8080/realms/catalog
- For development the Keycloak realm is included in `service-catalog/keycloak/realm-export.json` (dev-only)
