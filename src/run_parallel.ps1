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

# Optional run tag. When set, each p's output file is named
# p{p}q10_n{N}_{RUNTAG}_samples.csv AND per-chunk seeds are offset by a hash of
# the tag — a fresh tag produces fully independent samples safe to concatenate
# with a prior run via src/concat_samples.wl.
if ($env:RUNTAG) { $env:COMB_RUNTAG = $env:RUNTAG }
$tagLabel = if ($env:COMB_RUNTAG) { $env:COMB_RUNTAG } else { "(none)" }

Write-Host "Launching parallel runs with sampleSize = $N, runTag = $tagLabel"
Write-Host "Logs: $logsDir\compute_p{2,3,4}.log"

$logSuffix = if ($env:COMB_RUNTAG) { "_" + $env:COMB_RUNTAG } else { "" }
$jobs = @()
foreach ($p in 2, 3, 4) {
  $wrapper = Join-Path $srcDir ("run_p{0}.wl" -f $p)
  $logFile = Join-Path $logsDir ("compute_p{0}{1}.log" -f $p, $logSuffix)
  $errFile = Join-Path $logsDir ("compute_p{0}{1}.err" -f $p, $logSuffix)

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
