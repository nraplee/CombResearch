# comb_paths.ps1
# PowerShell twin of comb_paths.wl. Dot-source it from a launcher:
#   . (Join-Path $PSScriptRoot "comb_paths.ps1")
# Defines $CombRoot (main checkout, where data/figures/logs live),
# $CombDataDir, $CombFiguresDir, $CombLogsDir, $CombResultsDir. Run code from $PSScriptRoot,
# not $CombRoot\src, so a worktree runs its own scripts.
# Env COMB_ROOT overrides the output root.
# A failed git call is retried once; if it still fails in a linked worktree
# (.git is a file), the main checkout comes from that file's gitdir: line,
# else it throws (a launcher run with -File exits 1) rather than write into <worktree>\data.

# Main checkout of a linked worktree from its .git file, without git
# (twin of combPathsMainFromGitFile in comb_paths.wl). $null if not found.
function Get-CombMainFromGitFile([string]$codeRoot) {
  $gitFile = Join-Path $codeRoot ".git"
  if (!(Test-Path $gitFile -PathType Leaf)) { return $null }
  $line = Get-Content $gitFile | Where-Object { $_ -like "gitdir:*" } | Select-Object -First 1
  if (!$line) { return $null }
  $gitdir = $line.Substring(7).Trim()
  if (-not [IO.Path]::IsPathRooted($gitdir)) { $gitdir = Join-Path $codeRoot $gitdir }
  if (!(Test-Path $gitdir -PathType Container)) { return $null }
  $cdFile = Join-Path $gitdir "commondir"
  $cd = if (Test-Path $cdFile) { (Get-Content $cdFile | Select-Object -First 1) } else { $null }
  if ($cd) { $cd = $cd.Trim() }
  if (!$cd) { $common = Split-Path -Parent (Split-Path -Parent $gitdir) }
  elseif ([IO.Path]::IsPathRooted($cd)) { $common = $cd }
  else { $common = Join-Path $gitdir $cd }
  if (!(Test-Path $common -PathType Container)) { return $null }
  return Split-Path -Parent (Resolve-Path $common).Path
}

if ($env:COMB_ROOT) {
  $CombRoot = $env:COMB_ROOT
} else {
  $codeRoot = Split-Path -Parent $PSScriptRoot
  $common = $null
  foreach ($try in 1..2) {
    if (!(Get-Command git -ErrorAction SilentlyContinue)) { break }
    $out = git -C $PSScriptRoot rev-parse --git-common-dir 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) { $common = "$out".Trim(); break }
    if ($try -eq 1) { Start-Sleep -Seconds 1 }
  }
  # Relative to $PSScriptRoot on git < 2.31 (no --path-format); resolve it.
  if ($common -and -not [IO.Path]::IsPathRooted($common)) {
    $common = Join-Path $PSScriptRoot $common
  }
  if (!$common -and (Test-Path (Join-Path $codeRoot ".git") -PathType Leaf)) {
    # Git failed in a linked worktree: never fall back to the worktree.
    $main = Get-CombMainFromGitFile $codeRoot
    if ($main -and (Test-Path (Join-Path $main "src\comb_paths.wl"))) {
      Write-Host "comb_paths: git rev-parse failed; main checkout $main from $codeRoot\.git"
      $common = Join-Path $main ".git"
    } else {
      throw ("comb_paths: ERROR: git rev-parse failed in worktree $codeRoot and its .git file " +
        "does not lead to a CombResearch main checkout. Refusing to write outputs into the " +
        "worktree. Fix git or set COMB_ROOT to the main checkout.")
    }
  }
  if ($common -and (Test-Path $common)) {
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
