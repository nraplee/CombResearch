# sync_worktree_data.ps1
# Safety net for comb_paths.wl: copy generated files that a git worktree
# wrote into its own data/, figures/ or logs/ over to the main checkout
# ($CombRoot), which holds the one shared copy of all outputs.
#
# Only untracked and gitignored files are considered; tracked files travel
# through git. Never overwrites and never deletes:
#   - missing in main             -> copied to the same path
#   - identical in main           -> skipped
#   - different file in main      -> copied to
#       <main>\<dir>\_from_worktrees\<worktree-name>\<rest of path>
#     for a person to resolve, and reported as a conflict.
#
# Usage (from any checkout):
#   powershell -ExecutionPolicy Bypass -File src\sync_worktree_data.ps1
#   ... -DryRun    report what would be copied, copy nothing
#   ... -Quiet     print only when something was copied or conflicted
#                  (used by the Claude Code SessionStart hook)
# Env COMB_ROOT overrides the main checkout (see comb_paths.ps1).

param([switch]$DryRun, [switch]$Quiet)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "comb_paths.ps1")
$dirs = @("data", "figures", "logs", "results")

function Test-SameFile([string]$a, [string]$b) {
  $fa = Get-Item -LiteralPath $a; $fb = Get-Item -LiteralPath $b
  if ($fa.Length -ne $fb.Length) { return $false }
  if ($fa.LastWriteTimeUtc -eq $fb.LastWriteTimeUtc) { return $true }
  return (Get-FileHash -LiteralPath $a).Hash -eq (Get-FileHash -LiteralPath $b).Hash
}

function Copy-Preserving([string]$src, [string]$dst) {
  $parent = Split-Path -Parent $dst
  if (!(Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  Copy-Item -LiteralPath $src -Destination $dst   # keeps LastWriteTime
}

$worktrees = @(git -C $CombRoot worktree list --porcelain |
  Where-Object { $_ -like "worktree *" } |
  ForEach-Object { ($_.Substring(9)) -replace '/', '\' })

$copied = 0; $conflicts = 0; $skipped = 0
foreach ($wt in $worktrees) {
  if (!(Test-Path -LiteralPath $wt)) { continue }
  $wtFull = (Resolve-Path -LiteralPath $wt).Path
  if ($wtFull -eq $CombRoot) { continue }
  $wtName = Split-Path -Leaf $wtFull

  $raw = git -C $wtFull status --porcelain=v1 -z --ignored `
    --untracked-files=all -- @dirs 2>$null
  if (!$raw) { continue }
  $entries = ($raw -join "") -split "`0" | Where-Object { $_ -match '^(\?\?|!!) ' }
  foreach ($e in $entries) {
    $rel = $e.Substring(3) -replace '/', '\'
    if ($rel.EndsWith('\')) { continue }   # whole-dir entry; -uall should avoid
    if ($rel -match '\\_from_worktrees\\') { continue }
    $src = Join-Path $wtFull $rel
    if (!(Test-Path -LiteralPath $src -PathType Leaf)) { continue }
    $dst = Join-Path $CombRoot $rel

    if (!(Test-Path -LiteralPath $dst)) {
      Write-Host ("copy      {0}: {1}" -f $wtName, $rel)
      if (!$DryRun) { Copy-Preserving $src $dst }
      $copied++
    } elseif (Test-SameFile $src $dst) {
      $skipped++
    } else {
      $top, $rest = $rel -split '\\', 2
      $alt = Join-Path $CombRoot (Join-Path $top (Join-Path "_from_worktrees" (Join-Path $wtName $rest)))
      if ((Test-Path -LiteralPath $alt) -and (Test-SameFile $src $alt)) { $skipped++; continue }
      Write-Host ("CONFLICT  {0}: {1} differs from main -> {2}" -f $wtName, $rel, $alt)
      if (!$DryRun) { Copy-Preserving $src $alt }
      $conflicts++
    }
  }
}

if (!$Quiet -or $copied -gt 0 -or $conflicts -gt 0) {
  $mode = if ($DryRun) { " (dry run, nothing copied)" } else { "" }
  Write-Host ("sync_worktree_data: {0} copied, {1} conflicts, {2} already in {3}{4}" -f `
    $copied, $conflicts, $skipped, $CombRoot, $mode)
}
