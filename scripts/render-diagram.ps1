param(
    [string]$ImageName = "interop-infrastructure-mermaid:latest",
    [string]$Dockerfile = "docker/mermaid-render/Dockerfile"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")

Write-Host "Repository root: $($repoRoot.Path)"
Write-Host "Building Docker image '$ImageName' from Dockerfile '$Dockerfile'..."

$buildCmd = "docker build -t $ImageName -f $Dockerfile `"$($repoRoot.Path)`""
Write-Host $buildCmd
$build = Start-Process -FilePath docker -ArgumentList @('build','-t',$ImageName,'-f',$Dockerfile,$repoRoot.Path) -NoNewWindow -Wait -PassThru
if ($build.ExitCode -ne 0) {
    throw "Docker build failed with exit code $($build.ExitCode)"
}

Write-Host "Running renderer to produce admin-web/public/diagram.svg..."
$runArgs = @(
    'run','--rm',
    '--security-opt','seccomp=unconfined',
    '--cap-add','SYS_ADMIN',
    '--shm-size','1g',
    '-v',"$($repoRoot.Path):/workspace",
    '-w','/workspace',
    $ImageName,
    '-i','diagram.mmd','-o','admin-web/public/diagram.svg'
)
Write-Host "docker $($runArgs -join ' ')"
$run = Start-Process -FilePath docker -ArgumentList $runArgs -NoNewWindow -Wait -PassThru
if ($run.ExitCode -ne 0) {
    throw "Renderer run failed with exit code $($run.ExitCode)"
}

$outPath = Join-Path $repoRoot.Path 'admin-web\public\diagram.svg'
if (Test-Path $outPath) {
    $len = (Get-Item $outPath).Length
    Write-Host "Rendered: $outPath ($len bytes)"
} else {
    throw "diagram.svg not found after renderer run"
}

Write-Host "Done."
