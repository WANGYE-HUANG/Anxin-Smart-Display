param([string]$TdExe = 'D:/anlu TD/TD/bin/td_commands_prompt.exe')
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $TdExe)) { throw 'TD command-line executable was not found. Pass -TdExe with the local installation path.' }
$buildDir = Join-Path $PSScriptRoot ('build_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $buildDir -ErrorAction Stop | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'src/*') -Destination $buildDir
Push-Location -LiteralPath $buildDir
try {
    'source build.tcl' | & $TdExe -nogui 2>&1 | Tee-Object -FilePath 'build_console.log'
    if ($LASTEXITCODE -ne 0) { throw "TD returned exit code $LASTEXITCODE" }
    if (!(Test-Path -LiteralPath 'av_slide.bit')) { throw 'No bitstream generated. Inspect build_console.log and timing reports.' }
    Write-Host "Build complete: $buildDir/av_slide.bit"
} finally { Pop-Location }
