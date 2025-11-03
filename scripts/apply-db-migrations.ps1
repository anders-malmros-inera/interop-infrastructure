# Apply DB migrations found under service-catalog-db/migrations to the running DB container
# Usage: .\apply-db-migrations.ps1
$containerName = "interop-infrastructure-db-1"
if (-not (docker ps --format '{{.Names}}' | Select-String $containerName)) {
  Write-Error "Database container '$containerName' not running. Start the stack with docker-compose up -d and try again."
  exit 1
}
$migrations = Get-ChildItem -Path "$(Join-Path $PWD 'service-catalog-db' 'migrations')" -Filter "*.sql" | Sort-Object Name
if ($migrations.Count -eq 0) {
  Write-Host "No migrations found in service-catalog-db/migrations"
  exit 0
}
foreach ($m in $migrations) {
  $pathInContainer = "/tmp/" + $m.Name
  Write-Host "Applying migration: $($m.Name)"
  docker cp $m.FullName ($containerName + ":" + $pathInContainer)
  docker exec -i $containerName psql -U svcuser -d service_catalog -f $pathInContainer
}
Write-Host "Migrations applied."
