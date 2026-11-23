# run_p4q5_mh_parallel.ps1
# Launch three wolframscript processes in parallel - one per MH target
# at cell (p, q) = (4, 5). Each process writes its own log and WXF.
#
# Usage from the worktree root:
#   powershell -ExecutionPolicy Bypass -File src\run_p4q5_mh_parallel.ps1
#
# Optional env overrides (passed through to pipeline/30_mh.wl):
#   $env:COMB_MH_NUMITER = "500000"   # default 200000 in pipeline/30_mh.wl
#   $env:COMB_MH_BURNIN  = "50000"
#   $env:COMB_MH_THIN    = "5"
#   $env:COMB_MH_SEED    = "12345"
#   $env:COMB_MH_KERNEL  = "global"
#   $env:COMB_FORCE      = "1"         # overwrite existing WXFs
#
# Output:
#   data/p4q5_mh_{unlabeled,facet,vertex}.wxf
#   logs/mh_p4q5_{unlabeled,facet,vertex}.{log,err}
#
# Monitor with: powershell -ExecutionPolicy Bypass -File src\monitor_mh.ps1
# Stop early by killing the wolfram.exe processes via Task Manager or:
#   Get-Process wolfram | Stop-Process

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "comb_paths.ps1")
$root    = $CombRoot   # outputs: main checkout (comb_paths.ps1)
$srcDir  = $PSScriptRoot   # code: this checkout
$logsDir = Join-Path $root "logs"
if (!(Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }

$wrapper = Join-Path (Join-Path (Split-Path -Parent $srcDir) "pipeline") "30_mh.wl"
$targets = @("unlabeled", "facet", "vertex")

# Pinning settings printed for the log.
$numIter = if ($env:COMB_MH_NUMITER) { $env:COMB_MH_NUMITER } else { "200000" }
$burnIn  = if ($env:COMB_MH_BURNIN)  { $env:COMB_MH_BURNIN }  else { "20000" }
$thin    = if ($env:COMB_MH_THIN)    { $env:COMB_MH_THIN }    else { "5" }
$seed    = if ($env:COMB_MH_SEED)    { $env:COMB_MH_SEED }    else { "12345" }
$kernel  = if ($env:COMB_MH_KERNEL)  { $env:COMB_MH_KERNEL }  else { "global" }
$force   = if ($env:COMB_FORCE)      { $env:COMB_FORCE }      else { "0" }

Write-Host "==============================================="
Write-Host "(4,5) MH parallel launch"
Write-Host "==============================================="
Write-Host "  cell        = (4, 5)"
Write-Host "  targets     = $($targets -join ', ')"
Write-Host "  numIter     = $numIter"
Write-Host "  burnIn      = $burnIn"
Write-Host "  thin / seed = $thin / $seed"
Write-Host "  kernel      = $kernel"
Write-Host "  force       = $force"
Write-Host "  wrapper     = $wrapper"
Write-Host "  logs        = $logsDir\mh_p4q5_*.log"
Write-Host ""

# Always set cells; targets is set per-iteration below.
$env:COMB_MH_CELLS   = "4,5"
$env:COMB_MH_NUMITER = $numIter
$env:COMB_MH_BURNIN  = $burnIn
$env:COMB_MH_THIN    = $thin
$env:COMB_MH_SEED    = $seed
$env:COMB_MH_KERNEL  = $kernel
if ($force -eq "1") { $env:COMB_FORCE = "1" }

$jobs = @()
foreach ($target in $targets) {
  # Important: Start-Process snapshots env at invocation time, so per-target
  # COMB_MH_TARGETS is captured correctly even though we're mutating the
  # parent shell's env between iterations.
  $env:COMB_MH_TARGETS = $target

  $logFile = Join-Path $logsDir ("mh_p4q5_{0}.log" -f $target)
  $errFile = Join-Path $logsDir ("mh_p4q5_{0}.err" -f $target)

  Write-Host "  starting target = $target"
  Write-Host "    log  = $logFile"
  Write-Host "    err  = $errFile"

  $p = Start-Process wolframscript `
    -ArgumentList @("-file", $wrapper) `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError  $errFile `
    -PassThru -NoNewWindow
  $jobs += [pscustomobject]@{ Target = $target; Process = $p }
}

Write-Host ""
Write-Host "Launched $($jobs.Count) processes. PIDs:"
foreach ($j in $jobs) {
  Write-Host ("  {0,-10} PID {1}" -f $j.Target, $j.Process.Id)
}
Write-Host ""
Write-Host "This launcher will now WAIT for all three to finish."
Write-Host "If you want it to return immediately, kill this PowerShell"
Write-Host "(Ctrl-C) - the wolframscript children are detached and will"
Write-Host "continue running."
Write-Host ""
Write-Host "Monitor live with:"
Write-Host "  powershell -ExecutionPolicy Bypass -File src\monitor_mh.ps1"
Write-Host ""

$jobs.Process | Wait-Process

Write-Host ""
Write-Host "==============================================="
Write-Host "All three (4,5) MH processes have exited."
Write-Host "==============================================="
foreach ($j in $jobs) {
  $logFile = Join-Path $logsDir ("mh_p4q5_{0}.log" -f $j.Target)
  Write-Host "----- $($j.Target) -----"
  if (Test-Path $logFile) {
    Get-Content $logFile -Tail 6 | ForEach-Object { Write-Host "  $_" }
  } else {
    Write-Host "  (no log file)"
  }
}
