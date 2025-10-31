param(
    [int]$maxAttempts = 10,
    [int]$waitBetweenAttemptsSec = 5
)

function Run-Attempt {
    param($attempt)
    Write-Host "=== Attempt $attempt/$maxAttempts ==="

    Push-Location "$(Split-Path -Path $MyInvocation.MyCommand.Definition -Parent)\.." | Out-Null
    # Ensure images are built (service-catalog and admin-runner may have changed)
    docker-compose build service-catalog admin-runner

    # Start required services
    docker-compose up -d keycloak postgres admin-runner

    # Give admin-runner a couple of seconds to initialize
    Start-Sleep -Seconds 2

    # Trigger admin-runner to run tests
    try {
        Invoke-RestMethod -Uri http://localhost:8081/run-tests -Method Post -TimeoutSec 30
    } catch {
        Write-Warning "Trigger failed: $_. Retrying after short wait"
        Start-Sleep -Seconds 2
    }

    # Stream admin-runner logs and also capture to a file
    $logFile = "C:\\dev\\workspace\\interop-infrastructure\\logs\\admin-runner-attempt-$attempt.log"
    New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

    # Follow logs for up to 5 minutes or until we detect BUILD SUCCESS/FAILURE
    $timeout = [DateTime]::UtcNow.AddMinutes(5)

    $foundSuccess = $false
    $foundFailure = $false

    Write-Host "Tailing logs (timeout in 5m). Output saved to $logFile"
    $proc = Start-Process -FilePath docker-compose -ArgumentList 'logs','--no-color','--follow','admin-runner' -NoNewWindow -RedirectStandardOutput $logFile -PassThru

    while ((Get-Date) -lt $timeout) {
        if (Test-Path $logFile) {
            $content = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
            if ($content -match 'BUILD SUCCESS') { $foundSuccess = $true; break }
            if ($content -match 'BUILD FAILURE' -or $content -match 'Failed to execute goal') { $foundFailure = $true; break }
        }
        Start-Sleep -Seconds 2
    }

    # Stop tail process
    if ($proc -and -not $proc.HasExited) { $proc.Kill() | Out-Null }

    if ($foundSuccess) {
        Write-Host "Tests passed on attempt $attempt"
        return @{ Success = $true; Log = $logFile }
    }
    elseif ($foundFailure) {
        Write-Warning "Tests failed on attempt $attempt. See $logFile"
        return @{ Success = $false; Log = $logFile }
    } else {
        Write-Warning "No conclusive result within timeout on attempt $attempt. See $logFile"
        return @{ Success = $false; Log = $logFile }
    }
}

# main loop
for ($i = 1; $i -le $maxAttempts; $i++) {
    $r = Run-Attempt -attempt $i
    if ($r.Success) { Write-Host "All good. Exiting."; exit 0 }
    else {
        Write-Host "Attempt $i failed. Waiting $waitBetweenAttemptsSec seconds before next attempt. Log: $($r.Log)"
        Start-Sleep -Seconds $waitBetweenAttemptsSec
    }
}

Write-Error "Reached max attempts ($maxAttempts) without success. Inspect logs in scripts/logs/"
exit 1
