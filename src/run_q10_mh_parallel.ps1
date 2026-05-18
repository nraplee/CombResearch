# run_q10_mh_parallel.ps1
# Production 200k-iter MH chains at q=10 for the 4 IS-vs-MH disagreement
# cells: (3,10) and (4,10) x {unlabeled, facet}. Pilot at 10k iters showed
# L1 vs IS in [0.47, 1.35] with accept rates 9-19%; chains likely hadn't
# equilibrated. This rerun matches the production budget that worked at
# (4,5): 200k iter, 20k burn-in, thin 5 -> 36k kept states.
#
# Launches 4 wolframscript processes in parallel (one per cell x target)
# and waits. Writes per-process logs to logs/mh_q10_prod_*.log.
# Output: data/p{p}q10_mh_{target}.wxf  (overwrites pilot results)

$ErrorActionPreference = "Stop"
$repoRoot = "C:\CombResearch"
$srcDir   = Join-Path $repoRoot "src"
$logDir   = Join-Path $repoRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$numIter = if ($env:COMB_PROD_NUMITER) { $env:COMB_PROD_NUMITER } else { "200000" }
$burnIn  = if ($env:COMB_PROD_BURNIN)  { $env:COMB_PROD_BURNIN }  else { "20000"  }
$thin    = if ($env:COMB_PROD_THIN)    { $env:COMB_PROD_THIN }    else { "5"      }

$jobs = @(
  @{p=3; target="unlabeled"},
  @{p=3; target="facet"},
  @{p=4; target="unlabeled"},
  @{p=4; target="facet"}
)

Write-Host "q=10 MH production: numIter=$numIter burnIn=$burnIn thin=$thin"
Write-Host "Launching $($jobs.Count) parallel chains."

$procs = @()
foreach ($j in $jobs) {
  $p = $j.p; $target = $j.target
  $logFile = Join-Path $logDir "mh_q10_prod_p${p}_${target}.log"
  Write-Host "  -> p=$p target=$target  log=$logFile"
  $envBlock = @"
`$env:COMB_MH_CELLS   = '$p,10'
`$env:COMB_MH_TARGETS = '$target'
`$env:COMB_MH_NUMITER = '$numIter'
`$env:COMB_MH_BURNIN  = '$burnIn'
`$env:COMB_MH_THIN    = '$thin'
`$env:COMB_FORCE      = '1'
wolframscript -file '$(Join-Path $srcDir "run_mh_chains.wl")' *>&1 |
  Out-File -FilePath '$logFile' -Encoding utf8
"@
  $proc = Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-Command",$envBlock `
    -PassThru -WindowStyle Hidden
  $procs += @{proc=$proc; label="p${p}_${target}"}
}

Write-Host ""
Write-Host "Waiting for $($procs.Count) chains to finish..."
$t0 = Get-Date
foreach ($entry in $procs) {
  $entry.proc.WaitForExit()
  $dt = (Get-Date) - $t0
  Write-Host ("  [{0:HH:mm:ss}]  done: {1}  (exit {2})" -f (Get-Date), $entry.label, $entry.proc.ExitCode)
}
Write-Host ""
Write-Host "All chains complete."
