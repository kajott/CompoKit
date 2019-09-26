# a PowerShell implementation of https://keyj.emphy.de/balanced-shuffle/
#
# Takes any number of files or directories as inputs, and generates a
# playlist "shuffle.m3u" in the directory where the .ps1 file is located.
#
# In a CompoKit environment, the optional -Play parameter to play the
# generated playlist immediately with XMPlay.
#
# I'm pretty sure that there are more efficient ways to implement this,
# but it does its job well for smaller collections.

param(
    [parameter(ValueFromRemainingArguments=$true)] [string[]] $Sources,
    [switch] $Play
)

#Get-Random -SetSeed 0x13375EED >$null  # useful for debugging

function Pad-List ($data, $length) {
    # determine mode: generate marks or generate spaces?
    if ($data.Count -lt ($length / 2)) {
        $invert = $false
        $items = $data.Count
        $spaces = $length - $data.Count
    }
    else {
        $invert = $true
        $spaces = $data.Count
        $items = $length - $data.Count
    }

    # generate the pattern
    $pattern = ""
    while ($items -gt 0) {
        do {
            $pad = $spaces / $items
            if ($items -gt 1) {
                $delta = if (Get-Random -Maximum 2) { $pad } else { -0.5 * $pad }
                $pad += $delta * (Get-Random -Maximum 1.0) * (Get-Random -Maximum 1.0)
            }
        } until (($pad -ge 0) -and ($pad -le $spaces))
        $pad = [int] $pad
        $pattern += "X" + "-" * $pad
        $items--
        $spaces -= $pad
    }
    if ($pattern.Length -ne $length) { Write-Error "pattern-to-list length mismatch" }

    # apply a random shift
    $pivot = Get-Random -Maximum $length
    $pattern = $pattern.Substring($pivot) + $pattern.Substring(0, $pivot)

    # Write-Host $pattern

    # output data according to the pattern
    $i = 0
    foreach ($c in $pattern.toCharArray()) {
        $active = $c -eq "X"
        if ($invert) { $active = -not $active }
        if ($active) {
            $data[$i]
            $i++
        }
        else {
            $null
        }
    }
    if ($i -ne $data.Count) { Write-Error "padding output length mismatch" }
}

function Balanced-Shuffle ($inputs) {
    # split files and directories
    $files = @()
    $dirs = @()
    foreach ($f in $inputs) {
        $item = Get-Item -ErrorAction SilentlyContinue $f
        if ($item -is [System.IO.DirectoryInfo]) {
            $dirs += $f
        }
        elseif ($item -is [System.IO.FileInfo]) {
            $files += $f
        }
    }

    # collect lists to join, recurse into subdirectories
    $lists = @()
    if ($files) {
        $lists += , @($files | Sort-Object { Get-Random })
    }
    foreach ($d in $dirs) {
        Write-Host -ForegroundColor Gray "Scanning Directory:" $d
        $lists += , (Balanced-Shuffle (Resolve-Path -ErrorAction SilentlyContinue "$d\*" | select -ExpandProperty Path))
    }
    $n = $lists.Count

    # pad all lists to common length
    $maxl = ($lists | select -ExpandProperty Count | measure -Maximum).Maximum
    for ($i = 0;  $i -lt $n;  $i++) {
        if ($lists[$i].Count -lt $maxl) {
            $lists[$i] = Pad-List $lists[$i] $maxl
        }
    }
    $stats = $lists | select -ExpandProperty Count | measure -Minimum -Maximum
    if ($stats.Minimum -ne $stats.Maximum) { Write-Error "output list length mismatch" }

    # assemble output list
    $out = @()
    $lengths = @( $lists | select -ExpandProperty Count )
    $prevIdx = -1
    while ($true) {
        # determine maximum-length sublists
        $maxl = ($lengths | measure -Maximum).Maximum
        if ($maxl -lt 1) { break }
        $listIdx = (0..($n-1) | where { $lengths[$_] -eq $maxl })

        # select a list to sample from (but avoid repetitions)
        if ($listIdx.Count -gt 1) {
            $listIdx = ($listIdx | where { $_ -ne $prevIdx })
        }
        $listIdx = $listIdx[(Get-Random -Maximum $listIdx.Count)]

        # output the item and decrease the length
        $i = $lengths[$listIdx] - 1
        $lengths[$listIdx] = $i
        $i = $lists[$listIdx][$i]
        if ($i) {
            $i
            $prevIdx = $listIdx
        }
    }
}

$inputs = @()
foreach ($f in $Sources) {
    $inputs += Resolve-Path -ErrorAction SilentlyContinue $f | select -ExpandProperty Path
}

$myDir = Split-Path -Parent $PSCommandPath
$m3u = Join-Path $myDir "shuffle.m3u"
$xmplay = Join-Path (Split-Path -Parent $myDir) "bin\xmplay.exe"

if ($inputs) {
    Balanced-Shuffle $inputs | Out-File -Encoding UTF8 $m3u
    Write-Host -ForegroundColor Green "Created Playlist:" $m3u
    if ($Play -and (Test-Path $xmplay)) {
        & $xmplay $m3u
    }
}
else {
    rm -ErrorAction SilentlyContinue $m3u
}
