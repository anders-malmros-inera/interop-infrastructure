param(
    [string]$File,
    [switch]$DryRun
)

if (-not $File) { Write-Host "Usage: .\remove-index-and-numbers.ps1 -File <path-to-README.md> [-DryRun]"; exit 1 }
if (-not (Test-Path $File)) { Write-Host "File not found: $File"; exit 1 }

$lines = Get-Content -Path $File -Encoding utf8 -ErrorAction Stop
$lines = @($lines)

# Helper: detect fenced code blocks (``` or ~~~) and skip processing inside them
$inCode = $false

# 1) Remove explicit anchor lines like: <a id="sec-1-1-foo"></a>
$anchorPattern = '^[ \t]*<a\s+id="(?<id>[^"]+)"\s*>\s*</a>\s*$'
$out1 = @()
for ($i=0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    if ($ln -match '^[ \t]*(`{3,}|~{3,})') { $inCode = -not $inCode; $out1 += $ln; continue }
    if ($inCode) { $out1 += $ln; continue }
    if ($ln -match $anchorPattern) { continue } else { $out1 += $ln }
}
$lines = @($out1)

# 2) Remove a top-of-file Index block (either a header titled "Index" and following list, or a list of links before the first header)
function Remove-TopIndexBlock([string[]]$arr) {
    $linesLocal = @($arr)
    # find first header
    $firstHdr = -1
    for ($i=0; $i -lt $linesLocal.Length; $i++) { if ($linesLocal[$i] -match '^[ \t]*#{1,6}\s+') { $firstHdr = $i; break } }
    if ($firstHdr -le 0) { return $linesLocal }

    # check if there's a header titled Index within the initial block
    for ($i=0; $i -lt $firstHdr; $i++) {
        if ($linesLocal[$i] -match '^[ \t]*#{1,6}\s*Index\s*$') {
            # remove from this header line until just before next header
            $removeStart = $i
            $removeEnd = $firstHdr - 1
            $before = if ($removeStart -gt 0) { $linesLocal[0..($removeStart-1)] } else { @() }
            $after = $linesLocal[($removeEnd+1)..($linesLocal.Length-1)]
            return @($before + $after)
        }
    }

    # otherwise, examine the pre-header block: if it contains mostly list/link lines, remove it
    $block = $linesLocal[0..($firstHdr-1)]
    $nonblank = @()
    foreach ($b in $block) { if ($b -match '\S') { $nonblank += $b } }
    if ($nonblank.Count -eq 0) { return $linesLocal }
    $linkLike = 0
    foreach ($b in $nonblank) {
        if ($b -match '\]\(#' -or $b -match '<a\s+id=' -or $b -match '^[ \t]*[-*+]\s+' -or $b -match '^[ \t]*\d+\.') { $linkLike++ }
    }
    if ($linkLike -gt 0 -and ($linkLike / $nonblank.Count) -ge 0.25) {
        # remove block
        return @($linesLocal[$firstHdr..($linesLocal.Length-1)])
    }
    return $linesLocal
}

$lines = Remove-TopIndexBlock $lines

# 3) Remove numbering prefixes from header lines (outside code fences)
$inCode = $false
$out2 = @()
for ($i=0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    if ($ln -match '^[ \t]*(`{3,}|~{3,})') { $inCode = -not $inCode; $out2 += $ln; continue }
    if ($inCode) { $out2 += $ln; continue }
    if ($ln -match '^(?<hash>#{1,6}\s*)(?<num>[0-9]+(\.[0-9]+)*\.\s*)(?<rest>.*)$') {
        $new = $Matches['hash'] + $Matches['rest']
        $out2 += $new
    }
    else { $out2 += $ln }
}
$lines = @($out2)

# 4) Replace same-file anchor links [text](#anchor) with plain text when outside code fences
$inCode = $false
$out3 = @()
for ($i=0; $i -lt $lines.Length; $i++) {
    $ln = $lines[$i]
    if ($ln -match '^[ \t]*(`{3,}|~{3,})') { $inCode = -not $inCode; $out3 += $ln; continue }
    if ($inCode) { $out3 += $ln; continue }
    $pattern = '\[([^\]]+)\]\(#([^\)]+)\)'
    $matches = [regex]::Matches($ln, $pattern)
    if ($matches.Count -gt 0) {
        for ($m = $matches.Count - 1; $m -ge 0; $m--) {
            $mm = $matches[$m]
            $text = $mm.Groups[1].Value
            $start = $mm.Index
            $len = $mm.Length
            $ln = $ln.Substring(0, $start) + $text + $ln.Substring($start + $len)
        }
    }
    $out3 += $ln
}
$lines = @($out3)

# 4.1) Remove any remaining "Index" header blocks (header titled "Index" + following list) anywhere in the file
function Remove-IndexHeaderBlocks([string[]]$arr) {
    $L = @($arr)
    $i = 0
    $out = @()
    while ($i -lt $L.Length) {
        $ln = $L[$i]
    # match headers like: "## Index" or "## 1. Index" or "## 1.1. Index"
    if ($ln -match '^[ \t]*#{1,6}\s*(?:[0-9]+(\.[0-9]+)*\.\s*)?Index\b') {
            # skip this header
            $i = $i + 1
            # skip subsequent list/anchor/link lines until next header or blank+non-list
            while ($i -lt $L.Length) {
                $next = $L[$i]
                if ($next -match '^[ \t]*#{1,6}\s+') { break }
                if ($next -match '^[ \t]*([-*+]\s+|\d+\.\s+|<a\s+id=|\[.*\]\(#)') { $i = $i + 1; continue }
                if ($next -match '^\s*$') { $i = $i + 1; continue }
                # stop if we hit normal paragraph content
                break
            }
            continue
        }
        $out += $ln
        $i = $i + 1
    }
    return $out
}

$lines = Remove-IndexHeaderBlocks $lines

# Output
if ($DryRun) {
    Write-Host "----- DryRun preview for: $File -----"
    if ($lines.Length -eq 0) { Write-Host "(file is empty)" }
    else {
        $end = $lines.Length - 1
        if ($end -gt 80) { $end = 80 }
        for ($idx = 0; $idx -le $end; $idx++) { Write-Host $lines[$idx] }
    }
    Write-Host "----- end preview (total lines: $($lines.Length)) -----"
}
else {
    # Write a backup then overwrite
    Copy-Item -Path $File -Destination ($File + '.bak') -Force
    Set-Content -Path $File -Value ($lines -join "`n") -Encoding utf8
    Write-Host "Wrote: $File (backup: $File.bak)"
}

Write-Host "Done."
