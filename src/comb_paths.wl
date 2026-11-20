(* comb_paths.wl
   Where generated outputs live. Every script that reads or writes data/,
   figures/ or logs/ takes those directories from here, never from its own
   checkout, so runs from any git worktree share one copy of the data.

   The output root is the main checkout (C:\CombResearch on the Ryzen PC),
   found as the parent of `git rev-parse --git-common-dir`. That is the same
   directory from the main checkout and from every linked worktree. Code
   still runs from the checkout the script lives in; only outputs move.

   Why: data/*.wxf is gitignored and too large for git (~9 GB), so outputs
   written inside a worktree were stranded there (2026-11-20: the truth grid
   and all Phase 5a sampler WXFs existed only in one worktree).

   Idempotent: a second Get is a no-op.

   Env:
     COMB_ROOT   override the output root (e.g. a checkout without git, or a
                 scratch copy for tests). Default: the main checkout.

   Defines:
     $CombRoot        output root (main checkout)
     $CombCodeRoot    checkout this file was loaded from (parent of src/)
     $CombDataDir     $CombRoot/data
     $CombFiguresDir  $CombRoot/figures
     $CombLogsDir     $CombRoot/logs *)

If[!ValueQ[$CombRoot],
  Module[{here, env, common},
    here = If[ValueQ[$InputFileName] && $InputFileName =!= "",
      DirectoryName[$InputFileName], Directory[]];
    $CombCodeRoot = ParentDirectory[here];
    env = Environment["COMB_ROOT"];
    $CombRoot = If[StringQ[env] && StringLength[env] > 0,
      env,
      (* --git-common-dir is relative to `here` on git < 2.31, which lacks
         --path-format; resolve it against `here` in that case. *)
      common = Quiet @ RunProcess[{"git", "-C", here, "rev-parse",
        "--git-common-dir"}, "StandardOutput"];
      common = If[StringQ[common], StringTrim[common], ""];
      If[common =!= "" &&
          !StringMatchQ[common, RegularExpression["^([A-Za-z]:|/|\\\\).*"]],
        common = FileNameJoin[{here, common}]];
      If[common =!= "" && DirectoryQ[common],
        ParentDirectory[ExpandFileName[common]],
        Print["comb_paths: git not available; using ", $CombCodeRoot];
        $CombCodeRoot]];
    $CombRoot = ExpandFileName[$CombRoot];
    $CombDataDir = FileNameJoin[{$CombRoot, "data"}];
    $CombFiguresDir = FileNameJoin[{$CombRoot, "figures"}];
    $CombLogsDir = FileNameJoin[{$CombRoot, "logs"}];
    (* A fresh clone or a new machine may lack these; scripts only create
       their own subfolders. *)
    Scan[If[!DirectoryQ[#], CreateDirectory[#]] &,
      {$CombDataDir, $CombFiguresDir, $CombLogsDir}];
    If[ExpandFileName[$CombCodeRoot] =!= $CombRoot,
      Print["comb_paths: code from ", ExpandFileName[$CombCodeRoot],
        "; outputs to ", $CombRoot]]]];
