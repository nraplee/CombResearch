# run_parallel.ps1
# Launch three wolframscript processes in parallel — one per p value.
# Each process uses its own ParallelMap (sub-kernels) for the per-sample
# stats step, and writes data and logs to the standard layout.
#
# Usage from C:\CombResearch\:
#   powershell -ExecutionPolicy Bypass -File src\run_parallel.ps1
# Optional: pass a sample size override (default 500000) as $env:N
#   $env:N = 100000; powershell -ExecutionPolicy Bypass -File src\run_parallel.ps1

$ErrorActionPreference = "Stop"
$root    = Split-Path -Parent $PSScriptRoot   # parent of src/
$srcDir  = Join-Path $root "src"
$logsDir = Join-Path $root "logs"
if (!(Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }

# Sample size: env var N overrides default
$N = if ($env:N) { [int]$env:N } else { 500000 }
Write-Host "Launching parallel runs with sampleSize = $N"
Write-Host "Logs: $logsDir\compute_p{2,3,4}.log"

$jobs = @()
foreach ($p in 2, 3, 4) {
  $wrapper = Join-Path $srcDir ("run_p{0}.wl" -f $p)
  $logFile = Join-Path $logsDir ("compute_p{0}.log" -f $p)
  $errFile = Join-Path $logsDir ("compute_p{0}.err" -f $p)

  # Inject sampleSizeOverride before Get'ing the wrapper. The wrapper sets
  # pListOverride and useParallelOverride internally and then loads the main
  # script, so the only thing left to inject is N.
  $code = "sampleSizeOverride = $N; Get[`"$($wrapper -replace '\\','\\\\')`"]"

  Write-Host "  starting p = $p"
  $jobs += Start-Process wolframscript `
    -ArgumentList @("-code", $code) `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError  $errFile `
    -PassThru -NoNewWindow
}

Write-Host "Waiting for all three processes ..."
$jobs | Wait-Process
Write-Host "All three processes finished."
foreach ($j in $jobs) {
  Write-Host ("  PID {0}: ExitCode {1}" -f $j.Id, $j.ExitCode)
}
