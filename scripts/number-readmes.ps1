param(
    [string]$Root = $null,
    [switch]$DryRun
)

# Number Markdown headers in all README*.md files under this repository folder.
# For each file the numbering restarts at 1 for top-level headers.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $Root) { $Root = Resolve-Path (Join-Path $scriptDir '..') }
Write-Host "Scanning for README files under: $($Root.Path)"

# restrict search to the repo folder only, but exclude common vendor folders (node_modules, .git, vendor, dist, build)
$rawFiles = Get-ChildItem -Path $Root.Path -Recurse -Include 'README*.md' -File -ErrorAction SilentlyContinue
$files = $rawFiles | Where-Object {
    ($_.FullName -notmatch '\\node_modules\\') -and
    ($_.FullName -notmatch '\\[.]git\\') -and
    ($_.FullName -notmatch '\\vendor\\') -and
    ($_.FullName -notmatch '\\dist\\') -and
    ($_.FullName -notmatch '\\build\\')
}
if ($files.Count -eq 0) { Write-Host "No README files found (after exclusions)." }
foreach ($f in $files) {
    Write-Host "Processing: $($f.FullName)"
    $lines = Get-Content -Path $f.FullName -Encoding utf8 -ErrorAction Stop -WarningAction SilentlyContinue
    $counters = @(0,0,0,0,0,0)
    # We need to avoid matching headers inside fenced code blocks. Track code fence state.
    $inCodeBlock = $false
    # collect mapping of old anchor -> new anchor for updating internal links
    $anchorMap = @{}

    for ($i=0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        # toggle code fence state on lines that start a fenced block (```)
        if ($line -match '^[ \t]*```') {
            $inCodeBlock = -not $inCodeBlock
            continue
        }
        if ($inCodeBlock) { continue }

        # match markdown header lines like '# Title' or '### Title'
        if ($line -match '^(?<hash>#{1,6})\s*(?<title>.*)') {
            $hash = $Matches['hash']
            $level = $hash.Length
            # increment counters
            $counters[$level-1] = $counters[$level-1] + 1
            # zero out deeper levels
            for ($j = $level; $j -lt $counters.Length; $j++) { $counters[$j] = 0 }

            # build numbering like 1.2.3
            $parts = @()
            for ($k=0; $k -lt $level; $k++) {
                if ($counters[$k] -gt 0) { $parts += $counters[$k].ToString() }
            }
            $number = ($parts -join '.') + '.'

            # strip any existing leading numbering like '1.', '1.2.', '1) ', '1 -'
            $rawTitle = $Matches['title'] -replace '^[0-9]+(\.[0-9]+)*[\.)\-\s]*', ''
            $rawTitle = $rawTitle.Trim()
            $newTitle = "$number $rawTitle"
            $newLine = "$hash $newTitle"

            # compute old and new anchor slugs (GitHub-style): lower, remove punctuation, spaces -> '-'
            $ToSlug = {
                param($s)
                if (-not $s) { return '' }
                $s = $s.ToLowerInvariant()
                # remove leading numbering if any
                $s = $s -replace '^[0-9]+(\.[0-9]+)*[\.)\-\s]*',''
                # remove punctuation except spaces and hyphens
                $s = $s -replace "[^a-z0-9 \-]", ''
                $s = $s -replace '\\s+', ' '
                $s = $s.Trim()
                $s = $s -replace ' ', '-'
                return $s
            }

            $oldSlug = & $ToSlug $rawTitle
            $newSlug = & $ToSlug $newTitle
            if ($oldSlug -and ($oldSlug -ne $newSlug)) {
                $anchorMap[$oldSlug] = $newSlug
            }

            $lines[$i] = $newLine
        }
    }
    # After processing lines, update internal anchor links using the collected anchor map.
    if ($anchorMap.Count -gt 0) {
        # reset code block state for second pass
        $inCodeBlock = $false
        for ($i=0; $i -lt $lines.Length; $i++) {
            $line = $lines[$i]
            # skip code blocks when replacing links
            if ($line -match '^[ \t]*```') {
                $inCodeBlock = -not $inCodeBlock
                continue
            }
            if ($inCodeBlock) { continue }
            foreach ($old in $anchorMap.Keys) {
                $new = $anchorMap[$old]
                # replace links like ](#old) or ](./#old)
                $pattern = "\]\(#" + [Regex]::Escape($old) + "\)"
                $line = [Regex]::Replace($line, $pattern, "](#" + $new + ")", 'IgnoreCase')
                # also handle percent-encoded spaces (%20) in anchors
                $pattern2 = "\]\(#" + [Regex]::Escape(($old -replace ' ', '%20')) + "\)"
                $line = [Regex]::Replace($line, $pattern2, "](#" + $new + ")", 'IgnoreCase')
            }
            $lines[$i] = $line
        }
    }

    # write back or preview
    $out = $lines -join "`n"
    if ($DryRun) {
        Write-Host "Would write: $($f.FullName)"
    }
    else {
        Set-Content -Path $f.FullName -Value $out -Encoding utf8
        Write-Host "Wrote: $($f.FullName)"
    }
}

Write-Host "Done."
