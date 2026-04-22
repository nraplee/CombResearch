# run_parallel.ps1
# Launch three wolframscript processes in parallel — one per p value.
# Each process uses its own ParallelMap (sub-kernels) for the per-sample
# stats step, and writes data and logs to the standard layout.
#
# Usage from C:\CombResearch\:
#   powershell -ExecutionPolicy Bypass -File src\run_parallel.ps1
# Optional: pass a sample size override (default 500000) as $env:N
#   $env:N = 100000; powershell -ExecutionPolicy Bypass -File src\run_parallel.ps1
#
# Sample size is passed to Wolfram via the COMB_N environment variable
# (inherited by child processes). Each wrapper (run_p{2,3,4}.wl) reads
# COMB_N via `Environment["COMB_N"]` and falls back to 500000 if unset.

$ErrorActionPreference = "Stop"
$root    = Split-Path -Parent $PSScriptRoot   # parent of src/
$srcDir  = Join-Path $root "src"
$logsDir = Join-Path $root "logs"
if (!(Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }

# Sample size: env var N overrides default
$N = if ($env:N) { [int]$env:N } else { 500000 }
$env:COMB_N = "$N"
Write-Host "Launching parallel runs with sampleSize = $N (via COMB_N)"
Write-Host "Logs: $logsDir\compute_p{2,3,4}.log"

$jobs = @()
foreach ($p in 2, 3, 4) {
  $wrapper = Join-Path $srcDir ("run_p{0}.wl" -f $p)
  $logFile = Join-Path $logsDir ("compute_p{0}.log" -f $p)
  $errFile = Join-Path $logsDir ("compute_p{0}.err" -f $p)

  Write-Host "  starting p = $p"
  $jobs += Start-Process wolframscript `
    -ArgumentList @("-file", $wrapper) `
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
