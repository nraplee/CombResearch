# run_q10_mh_pilot.ps1
# Short MH pilot at q=10 for p in {2,3,4} and all three targets.
# Goal: measure wall-clock per cell x target, sanity-check numV
# distributions, before deciding production budget.
#
# Output: data/p{p}q10_mh_{target}.wxf via run_mh_chains.wl
# Logs:   logs/mh_q10_pilot_{p}_{target}.log
#
# Defaults: 10k iter, 1k burn-in, thin 2 -> ~4500 kept states.

$ErrorActionPreference = "Stop"
$repoRoot = "C:\CombResearch"
$srcDir   = Join-Path $repoRoot "src"
$logDir   = Join-Path $repoRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$numIter = if ($env:COMB_PILOT_NUMITER) { $env:COMB_PILOT_NUMITER } else { "10000" }
$burnIn  = if ($env:COMB_PILOT_BURNIN)  { $env:COMB_PILOT_BURNIN }  else { "1000"  }
$thin    = if ($env:COMB_PILOT_THIN)    { $env:COMB_PILOT_THIN }    else { "2"     }

Write-Host "q=10 MH pilot: numIter=$numIter  burnIn=$burnIn  thin=$thin"

foreach ($p in @(2, 3, 4)) {
  foreach ($target in @("vertex", "unlabeled", "facet")) {
    $cell    = "$p,10"
    $logFile = Join-Path $logDir "mh_q10_pilot_p${p}_${target}.log"
    Write-Host ""
    Write-Host "==== p=$p  target=$target  =>  $logFile"
    $env:COMB_MH_CELLS   = $cell
    $env:COMB_MH_TARGETS = $target
    $env:COMB_MH_NUMITER = $numIter
    $env:COMB_MH_BURNIN  = $burnIn
    $env:COMB_MH_THIN    = $thin
    $t0 = Get-Date
    wolframscript -file (Join-Path $srcDir "run_mh_chains.wl") *>&1 | Tee-Object -FilePath $logFile | Out-Null
    $dt = (Get-Date) - $t0
    Write-Host ("    wall: {0:N1} s" -f $dt.TotalSeconds)
  }
}

Write-Host ""
Write-Host "Pilot complete."
