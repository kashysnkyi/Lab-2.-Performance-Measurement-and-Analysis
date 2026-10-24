param([int] $N = 768, [int] $Repeats = 6, [int] $Trials = 5)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$counter = '\Energy Meter(RAPL_Package0_PKG)\Energy'
$rows = @()

function Read-Energy {
    [double](Get-Counter -Counter $counter -MaxSamples 1).CounterSamples[0].CookedValue
}

function Run-Program([string] $Path, [int] $Count) {
    for ($index = 0; $index -lt $Count; ++$index) {
        $process = Start-Process -FilePath $Path -ArgumentList @($N, $Repeats) -WindowStyle Hidden -PassThru -Wait
        if ($process.ExitCode -ne 0) { throw 'Program execution failed' }
    }
}

foreach ($variant in 'baseline','optimized') {
    $exe = Join-Path $root "build\bin\Release\matmul_$variant.exe"
    $calibration = [Diagnostics.Stopwatch]::StartNew()
    Run-Program $exe 1
    $calibration.Stop()
    $batch = [math]::Max(1, [math]::Ceiling(8.0 / $calibration.Elapsed.TotalSeconds))

    for ($trial = 1; $trial -le $Trials; ++$trial) {
        Start-Sleep -Seconds 2
        $startEnergy = Read-Energy
        $workloadTime = [Diagnostics.Stopwatch]::StartNew()
        Run-Program $exe $batch
        $workloadTime.Stop()
        $workloadEnergy = ((Read-Energy) - $startEnergy) * 3.6e-9

        Start-Sleep -Seconds 2
        $idleStart = Read-Energy
        $idleTime = [Diagnostics.Stopwatch]::StartNew()
        Start-Sleep -Milliseconds ([math]::Round($workloadTime.Elapsed.TotalMilliseconds))
        $idleTime.Stop()
        $idleEnergy = ((Read-Energy) - $idleStart) * 3.6e-9

        $rows += [pscustomobject]@{
            Variant = $variant
            Trial = $trial
            BatchRuns = $batch
            SecondsPerRun = $workloadTime.Elapsed.TotalSeconds / $batch
            PackageJoulesPerRun = $workloadEnergy / $batch
            IdleJoulesPerRun = $idleEnergy / $batch
            ProgramJoulesPerRun = ($workloadEnergy - $idleEnergy) / $batch
            WorkloadWatts = $workloadEnergy / $workloadTime.Elapsed.TotalSeconds
            IdleWatts = $idleEnergy / $idleTime.Elapsed.TotalSeconds
        }
    }
}

$rows | Export-Csv -NoTypeInformation -Encoding utf8 (Join-Path $root 'results\energy-results.csv')

function Get-Median([double[]] $Values) {
    $sorted = $Values | Sort-Object
    $middle = [math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2 -eq 0) {
        return ($sorted[$middle - 1] + $sorted[$middle]) / 2.0
    }
    return $sorted[$middle]
}

$summary = foreach ($group in ($rows | Group-Object Variant)) {
    $items = $group.Group
    [pscustomobject]@{
        Variant = $group.Name
        N = $N
        Repeats = $Repeats
        Trials = $items.Count
        BatchRuns = $items[0].BatchRuns
        MedianSecondsPerRun = Get-Median @($items.SecondsPerRun)
        MedianPackageJoulesPerRun = Get-Median @($items.PackageJoulesPerRun)
        MedianIdleJoulesPerRun = Get-Median @($items.IdleJoulesPerRun)
        MedianDynamicProgramJoulesPerRun = Get-Median @($items.ProgramJoulesPerRun)
        MedianWorkloadAverageWatts = Get-Median @($items.WorkloadWatts)
        MedianIdleAverageWatts = Get-Median @($items.IdleWatts)
    }
}

$summary | Export-Csv -NoTypeInformation -Encoding utf8 (Join-Path $root 'results\energy-summary.csv')

