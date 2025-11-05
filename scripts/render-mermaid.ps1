param()

# Simple PowerShell helper to regenerate all known Mermaid diagrams used in this repo.
# Requires Node/npm available on PATH. Uses npx to run mermaid-cli so no global install is required.

$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "Rendering Mermaid diagrams from repo root: $here"

function Render-Mermaid($inPath, $outPath) {
    Write-Host "Rendering $inPath -> $outPath"
    $cmd = "npx @mermaid-js/mermaid-cli -i `"$inPath`" -o `"$outPath`""
    & cmd /c $cmd
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Render failed for $inPath"
        exit $LASTEXITCODE
    }
}

# Ensure output directories exist
New-Item -ItemType Directory -Force -Path perl-api\docs\images | Out-Null
New-Item -ItemType Directory -Force -Path java-api\docs\images | Out-Null
New-Item -ItemType Directory -Force -Path perl-federation\docs\images | Out-Null

Render-Mermaid "perl-api/docs/info-model.mmd" "perl-api/docs/images/info-model.svg"
Render-Mermaid "java-api/docs/info-model.mmd" "java-api/docs/images/info-model.svg"
Render-Mermaid "perl-federation/docs/info-model.mmd" "perl-federation/docs/images/info-model.svg"

Write-Host "All diagrams rendered. Commit the updated SVGs if happy."
