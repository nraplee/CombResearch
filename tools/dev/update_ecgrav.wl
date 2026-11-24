(* update_ecgrav.wl
   Keep the shared clone of upstream ECGrav (github.com/kassabetre/ECGrav)
   at $CombRoot/ECGrav-upstream current with origin/main. Every script
   loads ECGrav from that clone through pipeline/common/ecgrav.wl, so all
   worktrees run the same commit. The folder is gitignored, like data/.

   Usage:
     wolframscript -file tools\dev\update_ecgrav.wl

   Clones on first use. Afterwards it fetches and fast-forwards to
   origin/main. It refuses (exit 1) when the clone has local changes or is
   not on main, so a fork branch being prepared for upstream is never moved
   by accident; develop those in a separate checkout and point
   COMB_ECGRAV_DIR at it instead.

   Run this only between runs: kernels that are already running keep the
   code they loaded. After an update, run tests\ecgrav_regression.wl
   (ecgrav.wl warns until the new commit has passed). *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName], 2],
  "pipeline", "common", "paths.wl"}]];

$upstreamURL = "https://github.com/kassabetre/ECGrav.git";

git[dir_, args__] := Module[{r = RunProcess[Join[{"git", "-C", dir}, {args}]]},
  If[!AssociationQ[r], Print["update_ecgrav: git not available"]; Exit[2]];
  If[r["ExitCode"] =!= 0,
    Print["update_ecgrav: git ", StringRiffle[{args}, " "], " failed:\n",
      r["StandardError"]]; Exit[2]];
  StringTrim[r["StandardOutput"]]];

Module[{dir, before, after, branch, dirty, haveGit},
  dir = FileNameJoin[{$CombRoot, "ECGrav-upstream"}];
  haveGit = AssociationQ[Quiet @ RunProcess[{"git", "--version"}]];
  (* Without git, or with an unpacked zip instead of a clone, ECGrav is
     managed by hand (Phase 7): use what is there, or say how to get it. *)
  If[!haveGit || (DirectoryQ[dir] && !DirectoryQ[FileNameJoin[{dir, ".git"}]]),
    If[DirectoryQ[dir],
      Print["update_ecgrav: ", If[haveGit, dir <> " is not a git clone",
        "git not available"], "; using ", dir,
        " as it is (not updated, commit unknown)."]; Exit[0],
      Print["update_ecgrav: git not available, so ECGrav cannot be cloned.\n",
        "  Download https://github.com/kassabetre/ECGrav/archive/refs/heads/main.zip,\n",
        "  unpack it and rename the folder to ", dir, "\n",
        "  (or set COMB_ECGRAV_DIR to any ECGrav checkout), then rerun run.wl check."];
      Exit[2]]];
  If[!DirectoryQ[dir],
    Print["update_ecgrav: cloning ", $upstreamURL, " -> ", dir];
    git[$CombRoot, "clone", "--branch", "main", $upstreamURL, dir]];
  branch = git[dir, "rev-parse", "--abbrev-ref", "HEAD"];
  dirty = git[dir, "status", "--porcelain"];
  If[branch =!= "main" || dirty =!= "",
    Print["update_ecgrav: ", dir, " is on '", branch, "'",
      If[dirty =!= "", " with local changes", ""],
      "; not touching it. Use COMB_ECGRAV_DIR for fork work."]; Exit[1]];
  before = git[dir, "rev-parse", "HEAD"];
  git[dir, "fetch", "--quiet", "origin", "main"];
  git[dir, "merge", "--ff-only", "--quiet", "origin/main"];
  after = git[dir, "rev-parse", "HEAD"];
  Print["update_ecgrav: ", dir];
  Print["  ", If[before === after, "already at ", "updated " <>
    StringTake[before, 7] <> " -> "], StringTake[after, 7], "  ",
    git[dir, "log", "-1", "--format=%cs %s"]];
  If[before =!= after,
    Print["  next: wolframscript -file tests/ecgrav_regression.wl"]]];
