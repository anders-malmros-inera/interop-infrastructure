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

    # First pass: collect headers while respecting fenced code blocks
    $headers = @()
    $inCodeBlock = $false
    for ($i=0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line -match '^[ \\t]*```') { $inCodeBlock = -not $inCodeBlock; continue }
        if ($inCodeBlock) { continue }
        if ($line -match '^(?<hash>#{1,6})\\s*(?<title>.*)') {
            # detect explicit anchor immediately above the header
            $anchorIndex = -1
            $anchorId = ''
            if ($i -gt 0 -and ($lines[$i-1] -match '<a\\s+id="(?<id>[^\"]+)"\\s*>\\s*</a>')) {
                $anchorIndex = $i-1
                $anchorId = $Matches['id']
            }
            $headers += [PSCustomObject]@{
                Index = $i
                Level = $Matches['hash'].Length
                RawTitle = ($Matches['title'] -replace '^[0-9]+(\.[0-9]+)*[\.)\-\s]*','').Trim()
                AnchorIndex = $anchorIndex
                AnchorId = $anchorId
            }
        }
    }

    # If no headers, skip
    if ($headers.Count -eq 0) { continue }

    # Compute numbering for headers
    $counters = @(0,0,0,0,0,0)
    $anchorMap = @{}
    $anchorIdMap = @{}
    $ToSlug = {
        param($s)
        if (-not $s) { return '' }
        $s = $s.ToLowerInvariant()
        $s = $s -replace '^[0-9]+(\.[0-9]+)*[\.)\-\s]*',''
        $s = $s -replace "[^a-z0-9 \-]", ''
        $s = $s -replace '\\s+', ' '
        $s = $s.Trim()
        $s = $s -replace ' ', '-'
        return $s
    }

    for ($hIndex = 0; $hIndex -lt $headers.Count; $hIndex++) {
        $h = $headers[$hIndex]
        $level = $h.Level
        # increment and reset counters
        $counters[$level-1] = $counters[$level-1] + 1
        for ($j = $level; $j -lt $counters.Length; $j++) { $counters[$j] = 0 }
        # build numbering string
        $parts = @()
        for ($k=0; $k -lt $level; $k++) { if ($counters[$k] -gt 0) { $parts += $counters[$k].ToString() } }
        $number = ($parts -join '.') + '.'
        $newTitle = "$number $($h.RawTitle)"
        $newHeaderLine = ('#' * $level) + ' ' + $newTitle

        # slugs and anchor ids
        $oldSlug = & $ToSlug $h.RawTitle
        $newSlug = & $ToSlug $newTitle
        if ($oldSlug -and ($oldSlug -ne $newSlug)) { $anchorMap[$oldSlug] = $newSlug }

        $numParts = @()
        for ($p=0; $p -lt $level; $p++) { $numParts += $counters[$p].ToString() }
        $numPrefix = ($numParts -join '-')
        $slugPart = if ($newSlug) { $newSlug } elseif ($oldSlug) { $oldSlug } else { 'section' }
        $newAnchorId = "sec-$numPrefix-$slugPart"
        if ($h.AnchorIndex -gt -1) {
            $oldAid = $h.AnchorId
            if ($oldAid -and ($oldAid -ne $newAnchorId)) { $anchorIdMap[$oldAid] = $newAnchorId }
        }

        # store new values back in headers array for second pass
        $headers[$hIndex].NewHeaderLine = $newHeaderLine
        $headers[$hIndex].NewAnchorId = $newAnchorId
        $headers[$hIndex].NewSlug = $newSlug
    }

    # Apply modifications in reverse order to avoid index shifts
    for ($hIndex = $headers.Count - 1; $hIndex -ge 0; $hIndex--) {
        $h = $headers[$hIndex]
        $idx = $h.Index
        # if existing anchor line present, replace it; else insert before header
        if ($h.AnchorIndex -gt -1) {
            $lines[$h.AnchorIndex] = '<a id="' + $h.NewAnchorId + '"></a>'
        }
        else {
            $before = if ($idx -gt 0) { $lines[0..($idx-1)] } else { @() }
            $after = $lines[$idx..($lines.Length-1)]
            $lines = $before + @('<a id="' + $h.NewAnchorId + '"></a>') + $after
        }
        # replace header line (note: if we inserted an anchor, header index moved +1)
        $headerPos = if ($h.AnchorIndex -gt -1) { $h.Index } else { $h.Index + 1 }
        $lines[$headerPos] = $h.NewHeaderLine
    }

    # Update same-file links: both slug-based links and explicit anchor id links
    $inCodeBlock = $false
    for ($i=0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line -match '^[ \\t]*```') { $inCodeBlock = -not $inCodeBlock; continue }
        if ($inCodeBlock) { continue }
        foreach ($old in $anchorMap.Keys) {
            $new = $anchorMap[$old]
            $pattern = "\\]\(#" + [Regex]::Escape($old) + "\\)"
            $line = [Regex]::Replace($line, $pattern, "](#" + $new + ")", 'IgnoreCase')
            $pattern2 = "\\]\(#" + [Regex]::Escape(($old -replace ' ', '%20')) + "\\)"
            $line = [Regex]::Replace($line, $pattern2, "](#" + $new + ")", 'IgnoreCase')
        }
        foreach ($old in $anchorIdMap.Keys) {
            $new = $anchorIdMap[$old]
            $pattern = "\\]\(#" + [Regex]::Escape($old) + "\\)"
            $line = [Regex]::Replace($line, $pattern, "](#" + $new + ")", 'IgnoreCase')
        }
        $lines[$i] = $line
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
