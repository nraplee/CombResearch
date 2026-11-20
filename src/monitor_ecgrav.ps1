# monitor_ecgrav.ps1
# Live dashboard for an ECGrav sampler campaign launched with
# src\run_ecgrav_campaign.ps1. Pure observer: reads logs and data/, never
# writes anything.
#
# Usage from the worktree root:
#   powershell -ExecutionPolicy Bypass -File src\monitor_ecgrav.ps1
#
# Optional env overrides:
#   $env:COMB_MON_SAMPLER  = "mcmc"   # which campaign to watch (default mcmc)
#   $env:COMB_MON_INTERVAL = "30"     # seconds between refreshes (default 30)
#   $env:COMB_MON_ONCE     = "1"      # print once and exit (no loop)
#
# Per target it shows: cells finished out of the planned list, the cell in
# progress and how long it has been running, the latest ECGrav diagnostics
# (eqlT, corrT, converged), and any error lines. Progress inside a cell is
# not visible: ECGrav's MCMC reports nothing until the cell finishes, so a
# long-running cell with no new lines is normal.
#
# Ctrl-C stops the monitor; the campaign keeps running.

$ErrorActionPreference = "Continue"

. (Join-Path $PSScriptRoot "comb_paths.ps1")
$root    = $CombRoot   # outputs: main checkout (comb_paths.ps1)
$logsDir = Join-Path $root "logs"
$dataDir = Join-Path $root "data"

$sampler  = if ($env:COMB_MON_SAMPLER)  { $env:COMB_MON_SAMPLER }       else { "mcmc" }
$interval = if ($env:COMB_MON_INTERVAL) { [int]$env:COMB_MON_INTERVAL } else { 30 }
$once     = ($env:COMB_MON_ONCE -eq "1")

$targets = @("unlabeled", "facet", "vertex")

function Format-Duration([double]$seconds) {
  $s = [int]$seconds
  "{0:00}:{1:00}:{2:00}" -f [int][Math]::Floor($s / 3600), [int][Math]::Floor(($s % 3600) / 60), ($s % 60)
}

function Show-Dashboard {
  Clear-Host
  Write-Host "================================================================"
  Write-Host "ECGrav campaign monitor   sampler = $sampler   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  Write-Host "================================================================"

  $procs = @(Get-Process -Name wolfram, WolframKernel -ErrorAction SilentlyContinue)
  Write-Host ""
  if ($procs.Count -eq 0) {
    Write-Host "Kernels: none running  (campaign finished, or not started)"
  } else {
    $mem = ($procs | Measure-Object WorkingSet64 -Sum).Sum / 1GB
    Write-Host ("Kernels: {0} running, {1:N1} GB total memory" -f $procs.Count, $mem)
  }

  foreach ($t in $targets) {
    $log = Join-Path $logsDir ("ecg{0}_{1}.log" -f $sampler, $t)
    $err = Join-Path $logsDir ("ecg{0}_{1}.err" -f $sampler, $t)
    Write-Host ""
    Write-Host "---- $t ".PadRight(64, "-")
    if (!(Test-Path $log)) { Write-Host "  (no log yet)"; continue }
    $lines = Get-Content $log -ErrorAction SilentlyContinue

    # Planned cells from the header line "cells           = {{2, 4}, ...}".
    $cellsLine = $lines | Where-Object { $_ -match "^cells\s+=" } | Select-Object -First 1
    $planned = if ($cellsLine) { ([regex]::Matches($cellsLine, "\{\d+, \d+\}")).Count } else { "?" }
    $done    = @($lines | Where-Object { $_ -match "^\s+wrote " }).Count
    $skipped = @($lines | Where-Object { $_ -match "exists, skipping" }).Count
    $finished = ($lines | Where-Object { $_ -cmatch "^done.$" }).Count -gt 0

    Write-Host ("  cells finished: {0} / {1}{2}{3}" -f $done, $planned,
      $(if ($skipped) { "  (+$skipped skipped, already on disk)" } else { "" }),
      $(if ($finished) { "   ** TARGET COMPLETE **" } else { "" }))

    # Cell in progress = last header line; elapsed from its timestamp.
    $hdr = $lines | Where-Object { $_ -match "^\(p, q\) = " } | Select-Object -Last 1
    if ($hdr -and -not $finished) {
      $cell = if ($hdr -match "^\(p, q\) = \((\d+), (\d+)\)") { "($($Matches[1]),$($Matches[2]))" } else { "?" }
      $elapsed = ""
      if ($hdr -match "started (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})") {
        $start = [datetime]::ParseExact($Matches[1], "yyyy-MM-dd HH:mm:ss", $null)
        $elapsed = "running " + (Format-Duration ((Get-Date) - $start).TotalSeconds)
      }
      Write-Host "  current cell:   $cell   $elapsed"
    }

    # Last finished cell's diagnostics.
    $eq = $lines | Where-Object { $_ -match "eqlT = " } | Select-Object -Last 1
    if ($eq) { Write-Host "  last MCMC diag: $($eq.Trim())" }
    $samp = $lines | Where-Object { $_ -match "^\s+sampled " } | Select-Object -Last 1
    if ($samp) { Write-Host "  last sampling:  $($samp.Trim())" }
    $um = $lines | Where-Object { $_ -match "unmatched samples" } | Select-Object -Last 1
    if ($um) { Write-Host "  last check:     $($um.Trim())" }

    # Problems: Wolfram messages (::), failures, non-convergence.
    $bad = @($lines | Where-Object { $_ -match "::|failed|Failed|OUTSIDE TRUTH|converged = False" })
    if (Test-Path $err) {
      $bad += @(Get-Content $err -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" })
    }
    if ($bad.Count -gt 0) {
      Write-Host "  !! $($bad.Count) warning/error line(s); latest:" -ForegroundColor Yellow
      $bad | Select-Object -Last 3 | ForEach-Object { Write-Host "     $($_.Trim())" -ForegroundColor Yellow }
    }
  }

  Write-Host ""
  $wxfs = @(Get-ChildItem $dataDir -Filter ("p*_ecg{0}_*.wxf" -f $sampler) -ErrorAction SilentlyContinue)
  Write-Host ("Output files in data/: {0}  (27 = full 9-cell grid)" -f $wxfs.Count)
  if (-not $once) { Write-Host "Refresh every ${interval}s. Ctrl-C stops the monitor, not the campaign." }
}

if ($once) { Show-Dashboard; exit }
while ($true) { Show-Dashboard; Start-Sleep -Seconds $interval }
