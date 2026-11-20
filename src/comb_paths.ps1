# comb_paths.ps1
# PowerShell twin of comb_paths.wl. Dot-source it from a launcher:
#   . (Join-Path $PSScriptRoot "comb_paths.ps1")
# Defines $CombRoot (main checkout, where data/figures/logs live),
# $CombDataDir, $CombFiguresDir, $CombLogsDir. Run code from $PSScriptRoot,
# not $CombRoot\src, so a worktree runs its own scripts.
# Env COMB_ROOT overrides the output root.

if ($env:COMB_ROOT) {
  $CombRoot = $env:COMB_ROOT
} else {
  # Relative to $PSScriptRoot on git < 2.31 (no --path-format); resolve it.
  $common = git -C $PSScriptRoot rev-parse --git-common-dir 2>$null
  if ($LASTEXITCODE -eq 0 -and $common -and -not [IO.Path]::IsPathRooted($common)) {
    $common = Join-Path $PSScriptRoot $common
  }
  if ($LASTEXITCODE -eq 0 -and $common -and (Test-Path $common)) {
    $CombRoot = Split-Path -Parent (Resolve-Path $common).Path
  } else {
    $CombRoot = Split-Path -Parent $PSScriptRoot
    Write-Host "comb_paths: git not available; using $CombRoot"
  }
}
$CombRoot       = (Resolve-Path $CombRoot).Path
$CombDataDir    = Join-Path $CombRoot "data"
$CombFiguresDir = Join-Path $CombRoot "figures"
$CombLogsDir    = Join-Path $CombRoot "logs"
foreach ($d in @($CombDataDir, $CombFiguresDir, $CombLogsDir)) {
  if (!(Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}
