param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$DockerArgs
)

<#
Wrapper: run README cleanup+renumbering then run `docker compose build`.

Usage examples:
  # Build normally (runs prebuild step first)
  .\build-with-readme-update.ps1

  # Pass arguments to docker compose build, e.g. --no-cache
  .\build-with-readme-update.ps1 -- --no-cache

Note: this wrapper runs `scripts/prebuild-readmes.ps1` (write mode) which will create/rotate .bak files.
#>

$script = Join-Path $PSScriptRoot 'scripts\prebuild-readmes.ps1'
if (-not (Test-Path $script)) { Write-Host "Prebuild script not found: $script"; exit 1 }

powershell -NoProfile -ExecutionPolicy Bypass -File $script

if ($DockerArgs -and $DockerArgs.Length -gt 0) {
    docker compose build $DockerArgs
} else {
    docker compose build
}

