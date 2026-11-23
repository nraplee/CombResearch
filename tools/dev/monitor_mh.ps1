# monitor_mh.ps1
# Live status display for running (4,5) MH chain processes.
# Polls wolfram.exe processes and the per-target log files; prints a
# refreshing dashboard.
#
# Usage from the worktree root:
#   powershell -ExecutionPolicy Bypass -File tools\dev\monitor_mh.ps1
#
# Optional env overrides:
#   $env:COMB_MON_INTERVAL = "10"    # seconds between refreshes (default 15)
#   $env:COMB_MON_CELL     = "4,5"   # cell to watch (default 4,5)
#   $env:COMB_MON_TAIL     = "4"     # log lines to show per target (default 4)
#
# Stops with Ctrl-C. Doesn't modify anything on disk; pure observer.

$ErrorActionPreference = "Continue"

# Code root: the folder above this script that holds run.wl.
$CombCodeRoot = $PSScriptRoot
while ($CombCodeRoot -and !(Test-Path (Join-Path $CombCodeRoot "run.wl"))) { $CombCodeRoot = Split-Path -Parent $CombCodeRoot }
if (!$CombCodeRoot) { throw "no run.wl above $PSScriptRoot" }
. (Join-Path $CombCodeRoot "pipeline\common\paths.ps1")
$root    = $CombRoot   # outputs: main checkout (paths.ps1)
$logsDir = Join-Path $root "logs"
$dataDir = Join-Path $root "data"

$interval = if ($env:COMB_MON_INTERVAL) { [int]$env:COMB_MON_INTERVAL } else { 15 }
$cell     = if ($env:COMB_MON_CELL)     { $env:COMB_MON_CELL }         else { "4,5" }
$tailN    = if ($env:COMB_MON_TAIL)     { [int]$env:COMB_MON_TAIL }    else { 4 }

# Convert cell "4,5" -> "p4q5" prefix used in filenames.
$pq = $cell.Split(",") | ForEach-Object { $_.Trim() }
$prefix = "p{0}q{1}" -f $pq[0], $pq[1]

$targets = @("unlabeled", "facet", "vertex")

function Format-Duration([int]$seconds) {
  # Cast to int explicitly — [Math]::Floor returns Double, and {0:D2}
  # only accepts Int. {0:00} accepts any numeric, so use that instead
  # and belt-and-suspenders cast.
  $h = [int][Math]::Floor($seconds / 3600)
  $m = [int][Math]::Floor(($seconds % 3600) / 60)
  $s = [int]($seconds % 60)
  "{0:00}:{1:00}:{2:00}" -f $h, $m, $s
}

function Format-MB([long]$bytes) {
  "{0,7:N1} MB" -f ($bytes / 1MB)
}

while ($true) {
  Clear-Host
  Write-Host "==============================================="
  Write-Host "MH chain monitor   cell = ($cell)   refresh = ${interval}s"
  Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  Write-Host "==============================================="

  # Wolfram processes summary.
  $wolframs = @(Get-Process -Name wolfram -ErrorAction SilentlyContinue)
  $scripts  = @(Get-Process -Name wolframscript -ErrorAction SilentlyContinue)

  Write-Host ""
  Write-Host "Live processes:"
  if ($wolframs.Count -eq 0 -and $scripts.Count -eq 0) {
    Write-Host "  (none)"
  } else {
    Write-Host ("  {0,-18} {1,8} {2,12} {3,14}" -f "Process", "PID", "CPU(hh:mm:ss)", "Memory")
    foreach ($p in $wolframs) {
      Write-Host ("  {0,-18} {1,8} {2,12} {3,14}" -f `
        "wolfram.exe", $p.Id, (Format-Duration([int]$p.CPU)), (Format-MB $p.WorkingSet64))
    }
    foreach ($p in $scripts) {
      Write-Host ("  {0,-18} {1,8} {2,12} {3,14}" -f `
        "wolframscript.exe", $p.Id, (Format-Duration([int]$p.CPU)), (Format-MB $p.WorkingSet64))
    }
  }

  # Per-target log tails + WXF state.
  Write-Host ""
  foreach ($target in $targets) {
    $logFile = Join-Path $logsDir ("mh_{0}_{1}.log" -f $prefix, $target)
    $wxfFile = Join-Path $dataDir ("{0}_mh_{1}.wxf" -f $prefix, $target)
    $hasWxf  = Test-Path $wxfFile

    Write-Host "-----------------------------------------------"
    if ($hasWxf) {
      $wxfSizeKB = [Math]::Round((Get-Item $wxfFile).Length / 1KB, 1)
      $wxfMtime  = (Get-Item $wxfFile).LastWriteTime.ToString("HH:mm:ss")
      Write-Host ("  target={0,-10}  WXF: {1,8} KB  (written {2})" -f `
        $target, $wxfSizeKB, $wxfMtime)
    } else {
      Write-Host ("  target={0,-10}  WXF: (not yet on disk)" -f $target)
    }

    if (Test-Path $logFile) {
      $logSizeKB = [Math]::Round((Get-Item $logFile).Length / 1KB, 1)
      Write-Host ("    log: $logFile  ($logSizeKB KB)")
      Write-Host "    tail:"
      try {
        Get-Content $logFile -Tail $tailN | ForEach-Object {
          Write-Host "      $_"
        }
      } catch {
        Write-Host "      (error reading log)"
      }
    } else {
      Write-Host ("    log: (not yet on disk: $logFile)")
    }
  }

  Write-Host ""
  Write-Host "Press Ctrl-C to stop monitoring. (Processes keep running.)"
  Start-Sleep -Seconds $interval
}
