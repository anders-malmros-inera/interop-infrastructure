param(
    [string]$File,
    [switch]$DryRun
)

if (-not $File) { Write-Host "Usage: .\renumber-readmes.ps1 -File <path-to-README.md> [-DryRun]"; exit 1 }
if (-not (Test-Path $File)) { Write-Host "File not found: $File"; exit 1 }

# Read file as array of lines
$origLines = Get-Content -Path $File -Encoding utf8 -ErrorAction Stop
$origLines = @($origLines)

# Helpers
function IsFenceLine($ln) {
    return ($ln -match '^[ \t]*(`{3,}|~{3,})')
}

function Slugify([string]$s) {
    if ($null -eq $s) { return "" }
    $t = $s.ToLower()
    # remove HTML tags
    $t = [regex]::Replace($t, '<[^>]+>', '')
    # replace non-alphanumeric with hyphen
    $t = [regex]::Replace($t, '[^a-z0-9]+', '-')
    # trim hyphens
    $t = $t.Trim('-')
    if ($t -eq '') { $t = 'section' }
    return $t
}

# First pass: collect headers (skip code fences)
$inCode = $false
$headers = @()
for ($i = 0; $i -lt $origLines.Length; $i++) {
    $ln = $origLines[$i]
    if (IsFenceLine $ln) { $inCode = -not $inCode; continue }
    if ($inCode) { continue }
    if ($ln -match '^[ \t]*(#{1,6})\s*(.*?)\s*$') {
        $level = $Matches[1].Length
        $rawText = $Matches[2]
        # strip any existing numeric prefix like '1.2. ' from captured text
        $text = $rawText -replace '^[ \t]*[0-9]+(\.[0-9]+)*\.\s*', ''
        # skip empty header text
        if ($text -match '^[ \t]*$') { continue }
        $slug = Slugify $text
        $headers += @(@{ Line = $i; Level = $level; Text = $text; Slug = $slug; IsDocHeader = $false })
    }
}

# Decide special-case: if exactly one level-1 header exists, treat it as document header (do not number it)
$top1 = @($headers | Where-Object { $_.Level -eq 1 })
$top1Count = $top1.Count
if ($top1Count -eq 1) {
    # Mark that header as document header
    foreach ($h in $headers) { if ($h.Level -eq 1) { $h.IsDocHeader = $true; break } }
}

# Compute numbering for headers (skip IsDocHeader)
# counters for levels 1..6 (index 1-based)
$counters = @(0,0,0,0,0,0,0)
# Will store mapping slug -> anchor id
$anchorMap = @{}
# We'll also store computed Number string for each header
# counter for simple level-2 numbering when a single top-level header exists
$top2ComputeCounter = 0
foreach ($h in $headers) {
    if ($h.IsDocHeader) { $h.Number = ''; $h.Anchor = 'doc-' + (Slugify $h.Text); continue }
    # effective depth: if doc header exists, shift levels down by 1
    $depth = $h.Level
    if ($top1Count -eq 1) { $depth = $h.Level - 1 }
    if ($depth -lt 1) { $depth = 1 }
    if ($depth -gt 6) { $depth = 6 }
    # increment counters
    $counters[$depth] = $counters[$depth] + 1
    # zero out deeper counters
    for ($k = $depth + 1; $k -le 6; $k++) { $counters[$k] = 0 }
    # build number string like 1.2.
    # Special case: if the file has a single top-level header, number level-2 headers as 1,2,3 (no parent prefix)
    if ($top1Count -eq 1 -and $h.Level -eq 2) {
        $top2ComputeCounter = $top2ComputeCounter + 1
        $numStr = $top2ComputeCounter.ToString() + '.'
        $parts = @($top2ComputeCounter.ToString())
    }
    else {
        $parts = @()
        for ($k = 1; $k -le $depth; $k++) { if ($counters[$k] -gt 0) { $parts += $counters[$k].ToString() } else { $parts += '0' } }
        $numStr = ($parts -join '.') + '.'
    }
    $h.Number = $numStr
    # build anchor id: sec-<numbers>-<slug>
    $numForId = ($parts -join '-')
    $slugPart = $h.Slug
    $aid = "sec-$numForId-$slugPart"
    # ensure uniqueness: append counter if needed
    $base = $aid
    $uc = 1
    while ($anchorMap.ContainsKey($aid)) {
        $aid = "$base-$uc"
        $uc = $uc + 1
    }
    $h.Anchor = $aid
    $anchorMap[$h.Slug] = $h.Anchor
    # compute display number (when a single top-level header exists, strip the leading parent prefix for level-2)
    if ($top1Count -eq 1 -and $h.Level -gt 1) {
        # remove first numeric prefix like 'N.' from 'N.M.' -> 'M.'
        $h.DisplayNumber = ($h.Number -replace '^[0-9]+\.', '')
    } else {
        $h.DisplayNumber = $h.Number
    }
}

# If exactly one top-level header exists, override level-2 numbering to be flat 1.,2.,3., and update anchors accordingly
if ($top1Count -eq 1) {
    $flat = 0
    foreach ($h in $headers) {
        if ($h.IsDocHeader) { continue }
        if ($h.Level -eq 2) {
            $flat = $flat + 1
            $h.Number = $flat.ToString() + '.'
            $h.DisplayNumber = $h.Number
            # rebuild anchor id using flat number
            $base = "sec-$flat-$($h.Slug)"
            $aid = $base
            $uc = 1
            while (($anchorMap.ContainsKey($aid) -and $anchorMap[$h.Slug] -ne $aid)) {
                $aid = "$base-$uc"
                $uc = $uc + 1
            }
            $h.Anchor = $aid
            $anchorMap[$h.Slug] = $h.Anchor
        }
    }
}

# Second pass: build new content, inserting anchors and numbered headers; also update same-file slug links to new anchors
$out = @()
$inCode = $false
$hdrIndex = 0
# simple counter for level-2 numbering when a single top-level header exists
# emission counter for level-2 headers when single top-level header exists
$top2Counter = 0
# We'll create a set of header slugs for quick lookup
$slugSet = @{}
foreach ($h in $headers) { $slugSet[$h.Slug] = $true }

for ($i = 0; $i -lt $origLines.Length; $i++) {
    $ln = $origLines[$i]
    if (IsFenceLine $ln) { $inCode = -not $inCode; $out += $ln; continue }
    if ($inCode) { $out += $ln; continue }
    # Skip existing explicit anchor-only lines like <a id="..."></a>
    if ($ln -match '^[ \t]*<a\s+id="(?<id>[^"]+)"\s*>\s*</a>\s*$') { continue }

    if ($ln -match '^[ \t]*(#{1,6})\s*(.*?)\s*$') {
        $level = $Matches[1].Length
        $text = $Matches[2]
        # match header in headers array at current file position
        # find next header entry whose Line >= i and not yet consumed
        $found = $null
        for ($j = $hdrIndex; $j -lt $headers.Count; $j++) {
            if ($headers[$j].Line -eq $i) { $found = $headers[$j]; $hdrIndex = $j + 1; break }
        }
        if ($null -eq $found) {
            # fallback: try matching by text
            foreach ($hh in $headers) { if ($hh.Text -eq $text -and -not $hh.Processed) { $found = $hh; $hh.Processed = $true; break } }
        }
        if ($null -ne $found) {
            # prepare header text without existing numbering prefix
            $cleanText = $text -replace '^[ \t]*[0-9]+(\.[0-9]+)*\.\s*', ''
            if ($found.IsDocHeader) {
                # write header as-is (no numbering), but add anchor for doc header
                $anchorLine = '<a id="' + $found.Anchor + '"></a>'
                $out += $anchorLine
                $out += ($Matches[1] + ' ' + $cleanText)
            }
            else {
                $num = $found.Number
                $anchorLine = '<a id="' + $found.Anchor + '"></a>'
                $out += $anchorLine
                # write header with numbering prefix
                $display = $num
                # If this file has a single top-level header, and this header is level-2 (i.e. '##'),
                # emit flat numbering 1.,2.,3. based on encountered order rather than hierarchical prefix.
                if ($top1Count -eq 1 -and $Matches[1].Length -eq 2) {
                    Write-Host "DEBUG: emitting flat level-2 counter at line $i"
                    $top2Counter = $top2Counter + 1
                    $display = $top2Counter.ToString() + '.'
                }
                $out += ($Matches[1] + ' ' + $display + ' ' + $cleanText)
            }
            continue
        }
    }

    # Update same-file anchor links: [text](#slug) -> [text](#sec-...)
    $line = $ln
    $pattern = '\[([^\]]+)\]\(#([^\)]+)\)'
    $linkMatches = [regex]::Matches($line, $pattern)
    if ($linkMatches.Count -gt 0) {
        # process from last to first to avoid index shifts
        for ($m = $linkMatches.Count - 1; $m -ge 0; $m--) {
            $mm = $linkMatches[$m]
            $linkText = $mm.Groups[1].Value
            $anchorTarget = $mm.Groups[2].Value
            $norm = $anchorTarget.ToLower()
            $norm = $norm.TrimStart('#')
            # if normalized anchor matches a header slug, replace with our new anchor id
            if ($slugSet.ContainsKey($norm)) {
                $newAid = $anchorMap[$norm]
                $start = $mm.Index
                $len = $mm.Length
                $line = $line.Substring(0, $start) + "[" + $linkText + "](#$newAid)" + $line.Substring($start + $len)
            }
        }
    }
    $out += $line
}

# Build Index block
$indexLines = @()
$indexLines += '# Index'
$indexLines += ''
foreach ($h in $headers) {
    if ($h.IsDocHeader) { continue }
    # effective depth
    $depth = $h.Level
    if ($top1Count -eq 1) { $depth = $h.Level - 1 }
    if ($depth -lt 1) { $depth = 1 }
    # indent: two spaces per depth-1 (avoid [Math]::Max in constrained mode)
    $spacesCount = ($depth - 1) * 2
    if ($spacesCount -lt 0) { $spacesCount = 0 }
    $indent = ' ' * $spacesCount
    # entry: - 1.2. Heading text
    $txt = $h.Text -replace '^[ \t]*[0-9]+(\.[0-9]+)*\.\s*', ''
    $numForIndex = $h.Number
    if ($top1Count -eq 1 -and $h.Level -eq 2) { $numForIndex = ($h.Number -replace '^[0-9]+\.', '') }
    $entry = "$indent- $($numForIndex) $txt  [↩](#$($h.Anchor))"
    $indexLines += $entry
}
$indexLines += ''

# Post-process content: if exactly one top-level header exists, force level-2 headers to display as flat 1.,2.,3.
if ($top1Count -eq 1) {
    # Build flat map by header order
    $flatMap = @{}
    $flatN = 0
    foreach ($h in $headers) {
        if ($h.IsDocHeader) { continue }
        if ($h.Level -eq 2) {
            $flatN = $flatN + 1
            $flatMap[$h.Slug] = $flatN
            # update header object's number/display for index rebuild
            $h.Number = $flatN.ToString() + '.'
            $h.DisplayNumber = $h.Number
            # update anchor to use flat prefix for readability
            $h.Anchor = 'sec-' + $flatN.ToString() + '-' + $h.Slug
            $anchorMap[$h.Slug] = $h.Anchor
        }
    }

    # Walk $out and replace any level-2 header lines in order with flat numbers.
    $flatCounter = 0
    for ($li = 0; $li -lt $out.Length; $li++) {
        $line = $out[$li]
        if ($line -match '^[ \t]*##\s*(?:[0-9]+(\.[0-9]+)*\.\s*)?(.*)$') {
            $flatCounter = $flatCounter + 1
            $rest = $Matches[2].Trim()
            # produce new header line
            $out[$li] = '## ' + $flatCounter.ToString() + '. ' + $rest
            # update preceding anchor line if present
            if ($li -gt 0 -and $out[$li - 1] -match '^[ \t]*<a\s+id="(?<id>[^"]+)"\s*>\s*</a>\s*$') {
                # find slug for rest
                $slug = Slugify $rest
                if ($flatMap.ContainsKey($slug)) {
                    $out[$li - 1] = '<a id="' + $anchorMap[$slug] + '"></a>'
                }
            }
        }
    }

    # Rebuild index lines using updated header info so Index shows flat numbers
    $newIndex = @()
    $newIndex += '# Index'
    $newIndex += ''
    foreach ($h in $headers) {
        if ($h.IsDocHeader) { continue }
        $depth = $h.Level
        if ($top1.Count -eq 1) { $depth = $h.Level - 1 }
        if ($depth -lt 1) { $depth = 1 }
        $spacesCount = ($depth - 1) * 2
        if ($spacesCount -lt 0) { $spacesCount = 0 }
        $indent = ' ' * $spacesCount
        $txt = $h.Text -replace '^[ \t]*[0-9]+(\.[0-9]+)*\.\s*', ''
        $numForIndex = $h.Number
        $entry = "$indent- $($numForIndex) $txt  [↩](#$($h.Anchor))"
        $newIndex += $entry
    }
    $newIndex += ''

    $indexLines = $newIndex
}

# Prepare final content: Index at very top + processed content
$final = @()
$final += $indexLines
$final += $out

if ($DryRun) {
    Write-Host "----- DryRun preview for: $File -----"
    # print first 120 lines as preview
    $limit = $final.Length - 1
    if ($limit -gt 120) { $limit = 120 }
    for ($i = 0; $i -le $limit; $i++) { Write-Host $final[$i] }
    Write-Host "----- end preview (total lines: $($final.Length)) -----"
    Write-Host "Processed headers: $($headers.Count)"
    Write-Host "Anchors (slug -> id):"
    foreach ($k in $anchorMap.Keys) { Write-Host "$k -> $($anchorMap[$k])" }
    Write-Host "Headers (Level | Number | DisplayNumber | Anchor | Text):"
    foreach ($hh in $headers) {
        Write-Host "$($hh.Level) | $($hh.Number) | $($hh.DisplayNumber) | $($hh.Anchor) | $($hh.Text)"
    }
}
else {
    # backup then write
    Copy-Item -Path $File -Destination ($File + '.bak') -Force
    Set-Content -Path $File -Value ($final -join "`n") -Encoding utf8
    Write-Host "Wrote: $File (backup: $File.bak)"
}

Write-Host "Done."
