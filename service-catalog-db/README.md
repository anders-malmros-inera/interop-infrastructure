# Index

- 1. Files of interest  [â†©](#sec-1-files-of-interest)
- 2. Applying migrations  [â†©](#sec-2-applying-migrations)
- 3. Migration guidelines  [â†©](#sec-3-migration-guidelines)

<a id="doc-service-catalog-db"></a>
# service-catalog-db

<a id="sec-1-files-of-interest"></a>
## 1. Files of interest

This folder builds the Postgres image used by the development stack and contains database initialization and migrations.

- `init.sql` — initialization SQL executed by the official Postgres image when a fresh data directory is created (applies only when the Postgres container starts with an empty volume). Put initial schema and seed data here.
- `migrations/` — idempotent SQL migrations that can be applied to an existing database instance. These are NOT automatically executed by the Postgres image for an existing (non-empty) volume. Place additive migrations here (use `CREATE TABLE IF NOT EXISTS` and `ALTER TABLE` statements where appropriate).

<a id="sec-2-applying-migrations"></a>
## 2. Applying migrations

For existing DB volumes, use the helper script in `scripts/apply-db-migrations.ps1` to copy and execute migration SQL files against the running DB container:

```powershell
cd C:\dev\workspace\interop-infrastructure
.\scripts\apply-db-migrations.ps1
```

If you prefer a fresh DB (warning: destroys existing data), you can recreate the DB volume so that `init.sql` runs on startup:

```powershell
docker compose -f docker-compose.yml down -v
docker compose -f docker-compose.yml up --build -d
```

<a id="sec-3-migration-guidelines"></a>
## 3. Migration guidelines

- Keep migrations small and additive.
- Prefer `CREATE TABLE IF NOT EXISTS` for new tables and `ALTER TABLE` for schema changes.
- Add a sequential numeric prefix to migration filenames (`0001_`, `0002_`, ...) so apply order is explicit.
