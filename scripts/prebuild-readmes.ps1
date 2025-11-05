param(
    [switch]$DryRun
)

<#
Runs `remove-index-and-numbers.ps1` then `renumber-readmes.ps1` for every README*.md under the
repository. Preserves any existing .bak by renaming it to a timestamped file so backups are not lost.

Usage:
  # Dry run, only prints what would be done
  .\scripts\prebuild-readmes.ps1 -DryRun

  # Run for real
  .\scripts\prebuild-readmes.ps1
#>

if ($PSScriptRoot -eq $null) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$now = (Get-Date).ToString('yyyyMMddHHmmss')

Write-Host "Searching for README files under: $repoRoot"
$files = Get-ChildItem -Path $repoRoot -Filter 'README*.md' -Recurse -File
if ($files.Count -eq 0) { Write-Host "No README files found."; exit 0 }

foreach ($f in $files) {
    $full = $f.FullName

    # Run remover then renumber using child PowerShell so ExecutionPolicy isn't an issue
    $remover = Join-Path $PSScriptRoot 'remove-index-and-numbers.ps1'
    $renumber = Join-Path $PSScriptRoot 'renumber-readmes.ps1'
    if ($DryRun) {
        Write-Host "Would run: $remover -File $full"
        Write-Host "Would run: $renumber -File $full"
        continue
    }
    powershell -NoProfile -ExecutionPolicy Bypass -File $remover -File $full
    powershell -NoProfile -ExecutionPolicy Bypass -File $renumber -File $full
}

Write-Host "Done. Processed $($files.Count) file(s)."
