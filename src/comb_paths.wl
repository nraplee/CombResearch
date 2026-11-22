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

   The git root is used only if it holds src/comb_paths.wl; otherwise (no
   git, or this tree unpacked inside an unrelated repo) the output root is
   the code checkout itself.

   If the git call fails it is retried once. If it still fails and the code
   checkout is a linked worktree (.git is a file, not a directory), the main
   checkout is read from that file's `gitdir:` line (plus the commondir file
   git keeps there); if that does not yield a CombResearch checkout the
   script stops (Exit[3], Abort[] in a notebook) instead of writing into
   <worktree>/data. 2026-11-21: one failed git call in a golden_derived.wl
   subprocess silently sent $CombDataDir to the worktree.

   Env:
     COMB_ROOT   override the output root (e.g. a checkout without git, or a
                 scratch copy for tests). Default: the main checkout.

   Defines:
     $CombRoot        output root (main checkout)
     $CombCodeRoot    checkout this file was loaded from (parent of src/)
     $CombDataDir     $CombRoot/data
     $CombFiguresDir  $CombRoot/figures
     $CombLogsDir     $CombRoot/logs
     $CombResultsDir  $CombRoot/results (small result tables, regression records) *)

(* Main checkout of a linked worktree from its .git file, without git:
   .git holds "gitdir: <main>/.git/worktrees/<name>", and that directory's
   commondir file holds the path of <main>/.git (relative to it, normally
   "../.."). Returns None when codeRoot is not a worktree or this fails. *)
combPathsMainFromGitFile[codeRoot_String] := Module[{gitFile, line, gitdir,
    cdFile, common},
  gitFile = FileNameJoin[{codeRoot, ".git"}];
  If[!FileExistsQ[gitFile] || DirectoryQ[gitFile], Return[None]];
  line = SelectFirst[Quiet @ ReadList[gitFile, String],
    StringStartsQ[#, "gitdir:"] &, None];
  If[!StringQ[line], Return[None]];
  gitdir = StringTrim[StringDrop[line, 7]];
  If[!StringMatchQ[gitdir, RegularExpression["^([A-Za-z]:|/|\\\\).*"]],
    gitdir = FileNameJoin[{codeRoot, gitdir}]];
  If[!DirectoryQ[gitdir], Return[None]];
  cdFile = FileNameJoin[{gitdir, "commondir"}];
  common = If[FileExistsQ[cdFile],
    StringTrim[First[Quiet @ ReadList[cdFile, String], ""]], ""];
  common = Which[
    common === "", ParentDirectory[ParentDirectory[gitdir]],
    StringMatchQ[common, RegularExpression["^([A-Za-z]:|/|\\\\).*"]], common,
    True, FileNameJoin[{gitdir, common}]];
  If[DirectoryQ[common], ParentDirectory[ExpandFileName[common]], None]];

If[!ValueQ[$CombRoot],
  Module[{here, env, common, gitCommon, fromFile},
    here = If[ValueQ[$InputFileName] && $InputFileName =!= "",
      DirectoryName[$InputFileName], Directory[]];
    $CombCodeRoot = ParentDirectory[here];
    env = Environment["COMB_ROOT"];
    $CombRoot = If[StringQ[env] && StringLength[env] > 0,
      env,
      (* --git-common-dir is relative to `here` on git < 2.31, which lacks
         --path-format; resolve it against `here` in that case. *)
      gitCommon[] := Module[{r = Quiet @ RunProcess[{"git", "-C", here,
          "rev-parse", "--git-common-dir"}]},
        If[AssociationQ[r] && r["ExitCode"] === 0,
          StringTrim[r["StandardOutput"]], ""]];
      common = gitCommon[];
      (* One retry: a transient failure is cheaper to absorb than to chase. *)
      If[common === "", Pause[1]; common = gitCommon[]];
      If[common =!= "" &&
          !StringMatchQ[common, RegularExpression["^([A-Za-z]:|/|\\\\).*"]],
        common = FileNameJoin[{here, common}]];
      common = If[common =!= "" && DirectoryQ[common],
        ParentDirectory[ExpandFileName[common]], None];
      Which[
        (* Git failed in a linked worktree: never fall back to the worktree
           itself, which would split the shared store. *)
        common === None && FileExistsQ[FileNameJoin[{$CombCodeRoot, ".git"}]] &&
            !DirectoryQ[FileNameJoin[{$CombCodeRoot, ".git"}]],
          fromFile = combPathsMainFromGitFile[$CombCodeRoot];
          If[StringQ[fromFile] &&
              FileExistsQ[FileNameJoin[{fromFile, "src", "comb_paths.wl"}]],
            Print["comb_paths: git rev-parse failed; main checkout ",
              fromFile, " from ", FileNameJoin[{$CombCodeRoot, ".git"}]];
            fromFile,
            Print["comb_paths: ERROR: git rev-parse failed in worktree ",
              $CombCodeRoot, " and its .git file does not lead to a ",
              "CombResearch main checkout. Refusing to write outputs into ",
              "the worktree. Fix git or set COMB_ROOT to the main checkout."];
            If[TrueQ[$Notebooks], Abort[], Exit[3]]],
        common === None,
          Print["comb_paths: git not available; using ", $CombCodeRoot];
          $CombCodeRoot,
        (* Repo-marker guard: a zip of this repo unpacked inside some other
           git repo would otherwise send outputs to that repo's root. *)
        !FileExistsQ[FileNameJoin[{common, "src", "comb_paths.wl"}]],
          Print["comb_paths: git root ", common,
            " is not a CombResearch checkout; using ", $CombCodeRoot];
          $CombCodeRoot,
        True, common]];
    $CombRoot = ExpandFileName[$CombRoot];
    $CombDataDir = FileNameJoin[{$CombRoot, "data"}];
    $CombFiguresDir = FileNameJoin[{$CombRoot, "figures"}];
    $CombLogsDir = FileNameJoin[{$CombRoot, "logs"}];
    $CombResultsDir = FileNameJoin[{$CombRoot, "results"}];
    (* A fresh clone or a new machine may lack these; scripts only create
       their own subfolders. *)
    Scan[If[!DirectoryQ[#], CreateDirectory[#]] &,
      {$CombDataDir, $CombFiguresDir, $CombLogsDir, $CombResultsDir}];
    If[ExpandFileName[$CombCodeRoot] =!= $CombRoot,
      Print["comb_paths: code from ", ExpandFileName[$CombCodeRoot],
        "; outputs to ", $CombRoot]]]];
