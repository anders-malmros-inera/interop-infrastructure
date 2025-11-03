# Restart Kong container to reload declarative config (kong.yml)
# Usage: .\reload-kong.ps1
$container = 'interop-kong-1'
if (-not (docker ps --format '{{.Names}}' | Select-String $container)) {
  Write-Error "Kong container '$container' not running. Start the stack with docker-compose up -d and try again."
  exit 1
}
Write-Host "Restarting Kong container '$container'..."
docker restart $container | Write-Host
Write-Host "Kong restarted. Give it a few seconds to warm up and load configuration."
