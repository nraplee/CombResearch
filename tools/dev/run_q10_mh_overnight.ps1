# run_q10_mh_overnight.ps1
# Overnight job for Phase 4c disambiguation: at the 4 IS-vs-MH
# disagreement cells (p in {3,4} x target in {unlabeled, facet}),
# run 1M-iter MH chains with a second seed (67890) and a warm-start
# init from numV above the previously-found region. Tests whether the
# 200k production chains were truly stationary or just trapped in a
# basin near the random-init.
#
# Steps:
#   1) Restore p4q10_mh_unlabeled.wxf at the production budget
#      (200k, seed 12345, default init) -- the prior smoke-test
#      clobber removed it.
#   2) Launch 4 parallel chains, 1M iter each, seed 67890,
#      warm-start at numV = 14 (p=3) or 18 (p=4), tag
#      "_seed67890_warm{N}". Outputs alongside the existing
#      p{p}q10_mh_{target}.wxf, never overwriting them.
#
# Total estimated wall: ~30 min restore + ~4-5 hr parallel = ~5 hr.
#
# All chains write to the main checkout's data/ (paths.ps1) via
# COMB_MH_OUTDIR.

$ErrorActionPreference = "Continue"
# Code root: the folder above this script that holds run.wl.
$CombCodeRoot = $PSScriptRoot
while ($CombCodeRoot -and !(Test-Path (Join-Path $CombCodeRoot "run.wl"))) { $CombCodeRoot = Split-Path -Parent $CombCodeRoot }
if (!$CombCodeRoot) { throw "no run.wl above $PSScriptRoot" }
. (Join-Path $CombCodeRoot "pipeline\common\paths.ps1")
$repoRoot   = $CombRoot        # outputs: main checkout
$srcDir     = $CombCodeRoot    # code: this checkout (folder holding run.wl)
$dataDir    = Join-Path $repoRoot "data"
$logDir     = Join-Path $repoRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$runScript  = Join-Path (Join-Path $srcDir "pipeline") "30_mh.wl"
Write-Host "using sampler driver: $runScript"

# --- Step 1: restore p4q10_mh_unlabeled.wxf (production 200k) ---
Write-Host ""
Write-Host "==== Step 1: restoring p4q10_mh_unlabeled.wxf (200k, default init) ===="
$restoreLog = Join-Path $logDir "mh_q10_restore_p4_unlabeled.log"
$env:COMB_MH_CELLS    = "4,10"
$env:COMB_MH_TARGETS  = "unlabeled"
$env:COMB_MH_NUMITER  = "200000"
$env:COMB_MH_BURNIN   = "20000"
$env:COMB_MH_THIN     = "5"
$env:COMB_MH_SEED     = "12345"
$env:COMB_MH_KERNEL   = "global"
$env:COMB_MH_TAG      = ""
Remove-Item Env:\COMB_MH_INITNUMV -ErrorAction SilentlyContinue
$env:COMB_MH_OUTDIR   = $dataDir
$env:COMB_FORCE       = "1"
$t0 = Get-Date
wolframscript -file $runScript *>&1 | Out-File -FilePath $restoreLog -Encoding utf8
$dt = (Get-Date) - $t0
Write-Host ("    restore wall: {0:N1} min" -f $dt.TotalMinutes)

# --- Step 2: 4 parallel chains, 1M iter, seed 67890, warm init ---
$jobs = @(
  @{p=3; target="unlabeled"; initNumV=14},
  @{p=3; target="facet";     initNumV=14},
  @{p=4; target="unlabeled"; initNumV=18},
  @{p=4; target="facet";     initNumV=18}
)

Write-Host ""
Write-Host "==== Step 2: launching $($jobs.Count) parallel chains @ 1M iter, seed 67890 ===="

$procs = @()
foreach ($j in $jobs) {
  $p = $j.p; $t = $j.target; $i = $j.initNumV
  $tag = "_seed67890_warm$i"
  $logFile = Join-Path $logDir "mh_q10_overnight_p${p}_${t}${tag}.log"
  Write-Host "  -> p=$p target=$t  warm@numV=$i  tag='$tag'  log=$logFile"
  $envBlock = @"
`$env:COMB_MH_CELLS    = '$p,10'
`$env:COMB_MH_TARGETS  = '$t'
`$env:COMB_MH_NUMITER  = '1000000'
`$env:COMB_MH_BURNIN   = '50000'
`$env:COMB_MH_THIN     = '20'
`$env:COMB_MH_SEED     = '67890'
`$env:COMB_MH_KERNEL   = 'global'
`$env:COMB_MH_TAG      = '$tag'
`$env:COMB_MH_INITNUMV = '$i'
`$env:COMB_MH_OUTDIR   = '$dataDir'
`$env:COMB_FORCE       = '1'
wolframscript -file '$runScript' *>&1 |
  Out-File -FilePath '$logFile' -Encoding utf8
"@
  $proc = Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-Command",$envBlock `
    -PassThru -WindowStyle Hidden
  $procs += @{proc=$proc; label="p${p}_${t}_warm${i}"}
}

Write-Host ""
Write-Host "Waiting for $($procs.Count) chains to finish (estimated wall ~4-5 hr)..."
$t0 = Get-Date
foreach ($entry in $procs) {
  $entry.proc.WaitForExit()
  $dt = (Get-Date) - $t0
  Write-Host ("  [{0:HH:mm:ss}]  done: {1}  (exit {2})  cum wall {3:N1} min" `
    -f (Get-Date), $entry.label, $entry.proc.ExitCode, $dt.TotalMinutes)
}

Write-Host ""
Write-Host "Overnight job complete."
