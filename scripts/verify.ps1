$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$baseline = Join-Path $root 'build\bin\Release\matmul_baseline.exe'
$optimized = Join-Path $root 'build\bin\Release\matmul_optimized.exe'
$baselineOutput = & $baseline 256 2
$baselineChecksum = if ($baselineOutput -match 'checksum=([0-9.eE+-]+)') { [double]$Matches[1] } else { throw 'Baseline checksum was not found' }
$optimizedOutput = & $optimized 256 2
$optimizedChecksum = if ($optimizedOutput -match 'checksum=([0-9.eE+-]+)') { [double]$Matches[1] } else { throw 'Optimized checksum was not found' }
$relativeError = [math]::Abs($optimizedChecksum - $baselineChecksum) / [math]::Abs($baselineChecksum)
$baselineOutput
$optimizedOutput
Write-Host "Relative checksum error: $relativeError"
if ($relativeError -gt 1e-5) { throw 'Checksum verification failed' }

