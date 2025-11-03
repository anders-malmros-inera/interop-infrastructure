# Changelog

All notable changes to this repository will be documented in this file.

## 2025-11-03 — Integration/tester and infra improvements

- Add: Federation membership service scaffold (`perl-federation`) with OpenAPI documentation and admin UI integration.
- Add: Kong declarative route for federation (`/federation`) and UI `APIs` tab updated to include Federation docs.
- Fix: Admin-web test-runner improved to probe candidate endpoints so tests work both from host and inside Docker networks.
- Add: Idempotent DB migration `service-catalog-db/migrations/0001_create_members.sql` to ensure `members` table exists.
- Add: `scripts/apply-db-migrations.ps1` helper to apply migrations to an existing DB container.
- Add: `scripts/reload-kong.ps1` helper to restart the Kong container and reload declarative config.
- Change: `federation` service removed host port mapping (no `ports: "5001:5001"`) — service is backend-only and reachable via Kong.
- Add: `admin-web` health-check endpoint `GET /api/health-check` to verify Kong routing and federation DB access.

