param([ValidateSet('hotspots','uarch')] [string] $Analysis = 'hotspots')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$vtune = Get-ChildItem 'C:\Program Files (x86)\Intel\oneAPI\vtune\*\bin64\vtune.exe' | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $vtune) { throw 'Intel VTune was not found' }

foreach ($variant in 'baseline','optimized') {
    $exe = Join-Path $root "build\bin\Release\matmul_$variant.exe"
    $result = Join-Path $root "results\vtune-$Analysis-$variant"
    if (Test-Path $result) {
        Remove-Item -LiteralPath $result -Recurse -Force
    }
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if ($Analysis -eq 'hotspots') {
        $repeatCount = if ($variant -eq 'baseline') { 20 } else { 200 }
        & $vtune -collect hotspots -knob sampling-mode=sw -result-dir $result -- $exe 768 $repeatCount
    } else {
        & $vtune -collect uarch-exploration -knob pmu-collection-mode=summary -result-dir $result -- $exe 768 6
    }
    $collectionExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    if ($collectionExitCode -ne 0) { throw "VTune collection failed for $variant" }
    $ErrorActionPreference = 'Continue'
    if ($Analysis -eq 'hotspots') {
        $reportPath = Join-Path $root "results\vtune-hotspots-$variant.csv"
        & $vtune -report hotspots -result-dir $result -format csv -csv-delimiter comma -report-output $reportPath
    } else {
        $reportPath = Join-Path $root "results\vtune-uarch-$variant.csv"
        & $vtune -report summary -result-dir $result -format csv -csv-delimiter comma -report-output $reportPath
    }
    $reportExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    if ($reportExitCode -ne 0) { throw "VTune report failed for $variant" }
    $cleanRows = Get-Content -LiteralPath $reportPath | Where-Object {
        $_ -notmatch 'Application Command Line|Computer Name'
    }
    $cleanRows | Set-Content -LiteralPath $reportPath -Encoding utf8
}

