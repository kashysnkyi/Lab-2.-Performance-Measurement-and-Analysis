param([ValidateSet('hotspots','uarch')] [string] $Analysis = 'hotspots')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$vtune = Get-ChildItem 'C:\Program Files (x86)\Intel\oneAPI\vtune\*\bin64\vtune.exe' | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $vtune) { throw 'Intel VTune was not found' }

foreach ($variant in 'baseline','optimized') {
    $exe = Join-Path $root "build\bin\Release\matmul_$variant.exe"
    $result = Join-Path $root "results\vtune-$Analysis-$variant"
    if ($Analysis -eq 'hotspots') {
        $repeatCount = if ($variant -eq 'baseline') { 20 } else { 200 }
        & $vtune -collect hotspots -knob sampling-mode=sw -result-dir $result -- $exe 768 $repeatCount
        & $vtune -report hotspots -result-dir $result -format csv -csv-delimiter comma -report-output (Join-Path $root "results\vtune-hotspots-$variant.csv")
    } else {
        & $vtune -collect uarch-exploration -knob pmu-collection-mode=summary -result-dir $result -- $exe 768 6
        & $vtune -report summary -result-dir $result -format csv -csv-delimiter comma -report-output (Join-Path $root "results\vtune-uarch-$variant.csv")
    }
    if ($LASTEXITCODE -ne 0) { throw "VTune failed for $variant" }
}

