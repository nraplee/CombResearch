# comb_paths.ps1
# PowerShell twin of comb_paths.wl. Dot-source it from a launcher:
#   . (Join-Path $PSScriptRoot "comb_paths.ps1")
# Defines $CombRoot (main checkout, where data/figures/logs live),
# $CombDataDir, $CombFiguresDir, $CombLogsDir, $CombResultsDir. Run code from $PSScriptRoot,
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
  $codeRoot = Split-Path -Parent $PSScriptRoot
  if ($LASTEXITCODE -eq 0 -and $common -and (Test-Path $common)) {
    $CombRoot = Split-Path -Parent (Resolve-Path $common).Path
    # Repo-marker guard (twin of comb_paths.wl): a zip unpacked inside an
    # unrelated git repo must not write into that repo's root.
    if (!(Test-Path (Join-Path $CombRoot "src\comb_paths.wl"))) {
      Write-Host "comb_paths: git root $CombRoot is not a CombResearch checkout; using $codeRoot"
      $CombRoot = $codeRoot
    }
  } else {
    $CombRoot = $codeRoot
    Write-Host "comb_paths: git not available; using $CombRoot"
  }
}
$CombRoot       = (Resolve-Path $CombRoot).Path
$CombDataDir    = Join-Path $CombRoot "data"
$CombFiguresDir = Join-Path $CombRoot "figures"
$CombLogsDir    = Join-Path $CombRoot "logs"
$CombResultsDir = Join-Path $CombRoot "results"
foreach ($d in @($CombDataDir, $CombFiguresDir, $CombLogsDir, $CombResultsDir)) {
  if (!(Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}
