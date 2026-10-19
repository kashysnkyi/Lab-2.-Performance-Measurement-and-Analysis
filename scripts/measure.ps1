param([int] $N = 768, [int] $Repeats = 6, [int] $Runs = 5)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root 'results\time-results.csv'
$rows = @()

foreach ($variant in 'baseline','optimized') {
    $exe = Join-Path $root "build\bin\Release\matmul_$variant.exe"
    for ($run = 1; $run -le $Runs; ++$run) {
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $exe
        $startInfo.Arguments = "$N $Repeats"
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        $watch = [Diagnostics.Stopwatch]::StartNew()
        [void]$process.Start()
        $peakMemory = 0L
        while (-not $process.WaitForExit(20)) {
            $process.Refresh()
            $peakMemory = [math]::Max($peakMemory, $process.WorkingSet64)
        }
        $text = $process.StandardOutput.ReadToEnd()
        $errorText = $process.StandardError.ReadToEnd()
        $watch.Stop()
        if ($process.ExitCode -ne 0) { throw $errorText }
        if ($text -notmatch 'kernel_seconds=([0-9.eE+-]+).*gflops=([0-9.eE+-]+).*checksum=([0-9.eE+-]+)') { throw 'Unexpected program output' }
        $rows += [pscustomobject]@{
            Variant = $variant
            Run = $run
            N = $N
            Repeats = $Repeats
            WallSeconds = $watch.Elapsed.TotalSeconds
            KernelSeconds = [double]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture)
            UserSeconds = $process.UserProcessorTime.TotalSeconds
            KernelCpuSeconds = $process.PrivilegedProcessorTime.TotalSeconds
            PeakWorkingSetMiB = $peakMemory / 1MB
            GFLOPS = [double]::Parse($Matches[2], [Globalization.CultureInfo]::InvariantCulture)
            Checksum = [double]::Parse($Matches[3], [Globalization.CultureInfo]::InvariantCulture)
        }
        Write-Host "$variant $run/$Runs $text"
        $process.Dispose()
    }
}

$rows | Export-Csv -NoTypeInformation -Encoding utf8 $output

