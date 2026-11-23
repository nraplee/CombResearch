# run_parallel.ps1
# Launch three wolframscript processes in parallel — one per p value.
# Each process uses its own ParallelMap (sub-kernels) for the per-sample
# stats step, and writes data and logs to the standard layout.
#
# Usage from the repo root:
#   powershell -ExecutionPolicy Bypass -File tools\dev\run_parallel.ps1
# Optional: pass a sample size override (default 500000) as $env:N
#   $env:N = 100000; powershell -ExecutionPolicy Bypass -File tools\dev\run_parallel.ps1
#
# Each process runs pipeline\20_is_q10.wl with COMB_IS_PS = its p,
# COMB_IS_PAR = 1 and COMB_N (inherited environment). run.wl is does the same
# from the profile's batch list; this launcher stays for ad-hoc batches.

$ErrorActionPreference = "Stop"
# Code root: the folder above this script that holds run.wl.
$CombCodeRoot = $PSScriptRoot
while ($CombCodeRoot -and !(Test-Path (Join-Path $CombCodeRoot "run.wl"))) { $CombCodeRoot = Split-Path -Parent $CombCodeRoot }
if (!$CombCodeRoot) { throw "no run.wl above $PSScriptRoot" }
. (Join-Path $CombCodeRoot "pipeline\common\paths.ps1")
$root    = $CombRoot   # outputs: main checkout (paths.ps1)
$srcDir  = $CombCodeRoot   # code: this checkout (folder holding run.wl)
$logsDir = Join-Path $root "logs"
if (!(Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }

# Sample size: env var N overrides default
$N = if ($env:N) { [int]$env:N } else { 500000 }
$env:COMB_N = "$N"

# Optional run tag. When set, each p's output file is named
# p{p}q10_n{N}_{RUNTAG}_samples.csv AND per-chunk seeds are offset by a hash of
# the tag — a fresh tag produces fully independent samples safe to concatenate
# with a prior run (pipeline/21_is_merge.wl, run.wl is).
if ($env:RUNTAG) { $env:COMB_RUNTAG = $env:RUNTAG }
$tagLabel = if ($env:COMB_RUNTAG) { $env:COMB_RUNTAG } else { "(none)" }

Write-Host "Launching parallel runs with sampleSize = $N, runTag = $tagLabel"
Write-Host "Logs: $logsDir\compute_p{2,3,4}.log"

$logSuffix = if ($env:COMB_RUNTAG) { "_" + $env:COMB_RUNTAG } else { "" }

# Which p values to launch. Default is {3, 4} (p=2 dropped — ESS at q=10 is
# healthy enough there that additional samples aren't needed, and freeing
# those 8 subkernels lets p=3 and p=4 run at full thread allocation on
# 8C/16T hardware). Override via $env:COMB_PLIST = "2,3,4" or "4" etc.
$plistSpec = if ($env:COMB_PLIST) { $env:COMB_PLIST } else { "3,4" }
$pList = @($plistSpec.Split(",") | ForEach-Object { [int]$_.Trim() })
Write-Host "  pList = $($pList -join ', ')"

$wrapper = Join-Path (Join-Path $srcDir "pipeline") "20_is_q10.wl"
$env:COMB_IS_PAR = "1"
$jobs = @()
foreach ($p in $pList) {
  $env:COMB_IS_PS = "$p"   # read by the child at start; set before each launch
  $logFile = Join-Path $logsDir ("compute_p{0}{1}.log" -f $p, $logSuffix)
  $errFile = Join-Path $logsDir ("compute_p{0}{1}.err" -f $p, $logSuffix)

  Write-Host "  starting p = $p"
  $jobs += Start-Process wolframscript `
    -ArgumentList @("-file", $wrapper) `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError  $errFile `
    -PassThru -NoNewWindow
  Start-Sleep -Seconds 1   # wolframscript can crash at start-up (0xC0000005) when several start at once
}

Write-Host "Waiting for $($jobs.Count) processes ..."
$jobs | Wait-Process
Write-Host "All processes finished."
foreach ($j in $jobs) {
  Write-Host ("  PID {0}: ExitCode {1}" -f $j.Id, $j.ExitCode)
}
