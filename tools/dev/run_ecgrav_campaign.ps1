# run_ecgrav_campaign.ps1
# Launch pipeline/40_ecgrav.wl as three parallel wolframscript
# processes (one per target) for a given sampler and cell list.
#
# Usage from the worktree root:
#   powershell -ExecutionPolicy Bypass -File tools\dev\run_ecgrav_campaign.ps1
#
# Env (passed through):
#   $env:COMB_ECG_SAMPLER = "exact"    # exact | mcmc
#   $env:COMB_ECG_CELLS   = "2,4;2,5;2,6;2,7;3,4;3,5;3,6;4,4;4,5"   (default)
#   $env:COMB_ECG_N       = "100000"   # default: 100000 exact, 20000 mcmc
#   $env:COMB_ECG_SEED    = "24680"
#   $env:COMB_FORCE       = "1"        # overwrite existing WXFs
#
# Output:
#   data/p{p}q{q}_ecg{sampler}_{target}.wxf
#   logs/ecg{sampler}_{target}.{log,err}
#
# Stop early: Get-Process wolfram | Stop-Process

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

$wrapper = Join-Path (Join-Path $srcDir "pipeline") "40_ecgrav.wl"
$targets = @("unlabeled", "facet", "vertex")
$sampler = if ($env:COMB_ECG_SAMPLER) { $env:COMB_ECG_SAMPLER } else { "exact" }
$cells   = if ($env:COMB_ECG_CELLS)   { $env:COMB_ECG_CELLS }   else { "2,4;2,5;2,6;2,7;3,4;3,5;3,6;4,4;4,5" }

$env:COMB_ECG_SAMPLER = $sampler
$env:COMB_ECG_CELLS   = $cells

Write-Host "ECGrav campaign: sampler=$sampler cells=$cells N=$($env:COMB_ECG_N)"

$jobs = @()
foreach ($target in $targets) {
  # Start-Process snapshots env at invocation time.
  $env:COMB_ECG_TARGETS = $target
  $logFile = Join-Path $logsDir ("ecg{0}_{1}.log" -f $sampler, $target)
  $errFile = Join-Path $logsDir ("ecg{0}_{1}.err" -f $sampler, $target)
  $p = Start-Process wolframscript `
    -ArgumentList @("-file", $wrapper) `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError  $errFile `
    -PassThru -NoNewWindow
  $jobs += [pscustomobject]@{ Target = $target; Process = $p }
  Write-Host ("  {0,-10} PID {1}  log {2}" -f $target, $p.Id, $logFile)
}

$jobs.Process | Wait-Process

Write-Host ""
Write-Host "All $sampler processes exited."
foreach ($j in $jobs) {
  $logFile = Join-Path $logsDir ("ecg{0}_{1}.log" -f $sampler, $j.Target)
  Write-Host "----- $($j.Target) -----"
  if (Test-Path $logFile) {
    Get-Content $logFile | Select-String "unmatched|sampled|FAIL|Failed|::" |
      ForEach-Object { Write-Host "  $_" }
  }
}
