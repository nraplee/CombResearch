(* ecgrav.wl
   The single entry point for ECGrav in this repo. Every script and library
   file loads ECGrav through this file, never through a bare Needs, so the
   master kernel and all subkernels run the same ECGrav checkout.

   Source, in order:
     1. COMB_ECGRAV_DIR, any ECGrav checkout (the folder holding
        PacletInfo.wl and Kernel/), e.g. a fork branch being prepared for
        upstream. "installed" = plain Needs["ECGrav`"] (global paclet).
     2. The shared clone of upstream main at $CombRoot/ECGrav-upstream,
        kept current by tools/dev/update_ecgrav.wl. All worktrees share it.

   Loads Kernel/ECGrav.wl directly with Get, bypassing the paclet system, so
   an older or newer globally installed paclet can never be picked up
   instead. ECGrav is never fetched here: updates happen only when
   update_ecgrav.wl runs, so a running job never changes code mid-run.

   After loading, checks that every ECGrav symbol this repo calls exists
   ($CombECGravSymbols), so an upstream rename fails here with one message
   instead of mid-run. Warns when the loaded commit has not yet passed
   tests/ecgrav_regression.wl.

   Idempotent: a second Get with the same source is a no-op, so library
   files (combresearch.wl, the pipeline stages) can load it
   unconditionally.

   Subkernels: call combLoadECGravOnKernels[] after LaunchKernels[] instead
   of ParallelEvaluate[Needs["ECGrav`"]].

   Defines:
     $CombECGravDir         checkout loaded (None in "installed" mode)
     $CombECGravCommit      full git commit ("<sha>-dirty" with local
                            changes; "unknown" without git)
     $CombECGravVersion     "<PacletInfo version>-<short sha>", e.g.
                            "1.18.0-474b5c2", for payload provenance
     $CombECGravKernelFile  Kernel/ECGrav.wl path (None when "installed") *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "paths.wl"}]];

(* Every ECGrav function this repo calls. Keep in sync with pipeline/, tests/ and CombResearch/. *)
$CombECGravSymbols = {
  "RandomVertexLabeledPureSimplicialComplex",
  "RandomUniformUnlabeledPureSimplicialComplex",
  "RandomUniformFacetLabeledPureSimplicialComplex",
  "RandomFacetLabeledPureSimplicialComplex",
  "RandomPureSimplicialComplexMCMC",
  "RandomPureSimplicialComplexMCMCSweep",
  "NumUnlabeledPureComplexes",
  "NumFacetLabeledPureComplexes",
  "NumVertexLabeledPureComplexes",
  "PureComplexAutomorphismGroupOrder",
  "PureComplexFacetAutomorphismGroupOrder",
  "IsomorphicSimplicialComplexQ",
  "ChooseNonIsomorphicSimplicialComplexes"};

(* Commit of an ECGrav checkout. Uses git only when dir is itself a repo
   root (a folder inside another repo would report that repo's HEAD), else
   a SOURCE_COMMIT.txt (vendored copies), else "unknown". *)
combECGravGitCommit[dir_] := Module[{top, r, sha, dirty, sc},
  top = Quiet @ RunProcess[{"git", "-C", dir, "rev-parse", "--show-toplevel"},
    "StandardOutput"];
  If[!StringQ[top] || ExpandFileName[StringTrim[top]] =!= ExpandFileName[dir],
    sc = FileNameJoin[{dir, "SOURCE_COMMIT.txt"}];
    Return[If[FileExistsQ[sc],
      First[StringCases[Import[sc, "Text"], RegularExpression["[0-9a-f]{40}"]],
        "unknown"],
      "unknown"]]];
  r = Quiet @ RunProcess[{"git", "-C", dir, "rev-parse", "HEAD"}];
  If[!AssociationQ[r] || r["ExitCode"] =!= 0, Return["unknown"]];
  sha = StringTrim[r["StandardOutput"]];
  dirty = Quiet @ RunProcess[{"git", "-C", dir, "status", "--porcelain",
    "--untracked-files=no"}, "StandardOutput"];
  If[StringQ[dirty] && StringTrim[dirty] =!= "", sha <> "-dirty", sha]];

combECGravPacletVersion[dir_] := Module[{pi},
  pi = Quiet @ Get[FileNameJoin[{dir, "PacletInfo.wl"}]];
  Which[
    MatchQ[pi, _PacletObject], pi["Version"],
    MatchQ[pi, _[___, "Version" -> _String, ___]], "Version" /. List @@ pi,
    True, "unknown"]];

combECGravRegressionFile[] := FileNameJoin[{$CombResultsDir,
  "ecgrav_regression_passed.wl"}];

combECGravCheck[] := Module[{missing, passed},
  missing = Select[$CombECGravSymbols,
    !MemberQ[Names["ECGrav`*"], #] ||
      ToExpression["ECGrav`" <> #, InputForm, Function[s, DownValues[s] === {} &&
        SubValues[s] === {}, HoldAll]] &];
  If[missing =!= {},
    Print["load_ecgrav: ECGrav ", $CombECGravVersion,
      " lacks functions this repo calls: ", missing,
      ". Upstream renamed or removed them; update the callers in pipeline/ and ",
      "$CombECGravSymbols."];
    Abort[]];
  passed = Quiet @ Get[combECGravRegressionFile[]];
  If[$CombECGravCommit =!= "installed" &&
      !(AssociationQ[passed] && passed["commit"] === $CombECGravCommit),
    Print["load_ecgrav: WARNING ECGrav ", $CombECGravVersion,
      " has not passed tests/ecgrav_regression.wl yet",
      If[AssociationQ[passed], " (last pass: " <> passed["version"] <> ")", ""],
      "."]]];

Module[{env, dir, kernelFile},
  env = Environment["COMB_ECGRAV_DIR"];
  dir = Which[
    StringQ[env] && env === "installed", "installed",
    StringQ[env] && StringLength[env] > 0, ExpandFileName[env],
    True, FileNameJoin[{$CombRoot, "ECGrav-upstream"}]];
  Which[
    ValueQ[$CombECGravDir] && ($CombECGravDir === dir ||
      ($CombECGravDir === None && dir === "installed")),
      Null,
    dir === "installed",
      Needs["ECGrav`"];
      $CombECGravDir = None;
      $CombECGravKernelFile = None;
      $CombECGravCommit = "installed";
      $CombECGravVersion = "installed-" <> ToString[
        Quiet @ First[PacletFind["ECGrav"], <|"Version" -> "?"|>]["Version"]];
      Print["ECGrav loaded: ", $CombECGravVersion, " (global paclet)"];
      combECGravCheck[],
    True,
      kernelFile = FileNameJoin[{dir, "Kernel", "ECGrav.wl"}];
      If[!FileExistsQ[kernelFile],
        Print["load_ecgrav: no ECGrav at ", dir, ". Run\n",
          "  wolframscript -file tools/dev/update_ecgrav.wl\n",
          "to clone upstream, or set COMB_ECGRAV_DIR to an ECGrav checkout."];
        Abort[]];
      If[MemberQ[$Packages, "ECGrav`"],
        Print["load_ecgrav: WARNING ECGrav` already loaded; reloading from ",
          dir]];
      Get[kernelFile];
      $CombECGravDir = dir;
      $CombECGravKernelFile = kernelFile;
      $CombECGravCommit = combECGravGitCommit[dir];
      $CombECGravVersion = combECGravPacletVersion[dir] <> "-" <>
        StringTake[$CombECGravCommit, UpTo[7]];
      Print["ECGrav loaded: ", $CombECGravVersion, " from ", dir];
      combECGravCheck[]];
];

combLoadECGravOnKernels[] := If[$CombECGravKernelFile === None,
  ParallelEvaluate[Needs["ECGrav`"]],
  With[{f = $CombECGravKernelFile},
    ParallelEvaluate[If[!MemberQ[$Packages, "ECGrav`"], Get[f]]]]];
