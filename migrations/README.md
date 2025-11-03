Migrations
==========

This folder should contain idempotent, ordered SQL migrations for the service database.

Recommendations:
- Use Flyway (Java) or a similar tool for schema management.
- Keep migrations in an ordered numeric prefix (0001_...).
