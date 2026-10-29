$ErrorActionPreference = 'Stop'
$count = 0
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'SHA256SUMS.txt'))) {
    if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { throw "Invalid checksum entry: $line" }
    $expected = $Matches[1]
    $relative = $Matches[2]
    $file = Join-Path $PSScriptRoot $relative
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing file: $relative" }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower() -ne $expected) { throw "Hash mismatch: $relative" }
    $count++
}
Write-Host "PASS: $count files verified."
