(* ::Package:: *)

(* Tests for MHSampler.wl: the numV marginal of short seeded chains at (2,4)
   against the exact marginal for each target (computed here from the
   enumerator and the statistics, no data files), reproducibility under a
   seed, the shape of the states, argument checks, and the autocorrelation
   estimator. Run with Tests/run_tests.wl (about 3 min). *)

If[!MemberQ[$Packages, "CombResearch`"],
  Get[FileNameJoin[{If[ValueQ[$CombResearchTestRoot], $CombResearchTestRoot,
    ParentDirectory[DirectoryName[$InputFileName]]], "Tests", "TestPrelude.wl"}]]];

mhTestNumV[c_] := Length[DeleteDuplicates[Flatten[c]]];

(* exact numV marginal at (p, q) for a target, from the iso classes *)
mhTestExact[p_, q_, target_] := Module[{reps, st, w},
  reps = EnumerateUnlabeledPureComplexes[p, q, Method -> "Cheap", "Parallel" -> False]["isoReps"];
  st = AssociationThread[$PureComplexStatisticNames -> PureComplexStatistics[#, p]] & /@ reps;
  w = Switch[target,
    "unlabeled", ConstantArray[1, Length[reps]],
    "facet", (q! / #["autF"]) & /@ st,
    "vertex", (#["numV"]! / #["aut"]) & /@ st];
  N[Merge[Thread[(#["numV"] & /@ st) -> w], Total] / Total[w]]];

mhTestL1[trace_, exact_] := Module[{c = N[Counts[mhTestNumV /@ trace] / Length[trace]], ks},
  ks = Union[Keys[c], Keys[exact]];
  Total[Abs[Lookup[c, ks, 0] - Lookup[exact, ks, 0]]]];

Do[With[{t = target},
    VerificationTest[
      mhTestL1[PureComplexMHChain[2, 4, t, 40000, "burnIn" -> 4000, "thin" -> 5,
        "seed" -> 4242, "verbose" -> False]["trace"], mhTestExact[2, 4, t]] < 0.06,
      True, TestID -> "numV-L1-24-" <> t]],
  {target, {"unlabeled", "facet", "vertex"}}];

VerificationTest[
  Module[{a, b},
    a = PureComplexMHChain[3, 4, "facet", 2000, "seed" -> 7, "thin" -> 10, "verbose" -> False];
    b = PureComplexMHChain[3, 4, "facet", 2000, "seed" -> 7, "thin" -> 10, "verbose" -> False];
    {a["trace"] === b["trace"], a["acceptRate"] === b["acceptRate"], Length[a["trace"]]}],
  {True, True, 200}, TestID -> "seed-reproducible"];

VerificationTest[
  With[{r = PureComplexMHChain[3, 4, "unlabeled", 1000, "kernel" -> "mixed", "verbose" -> False]},
    {r["N"], AllTrue[r["trace"], Function[x,
      Length[x] === 4 && DuplicateFreeQ[x] && OrderedQ[x] &&
      AllTrue[x, Length[#] === 3 && OrderedQ[#] && SubsetQ[Range[12], #] &]]]}],
  {12, True}, TestID -> "states-shape-mixed"];

VerificationTest[
  With[{r = PureComplexMHChain[2, 5, "vertex", 500, "initNumV" -> 5, "kernel" -> "local",
      "verbose" -> False]},
    Length[r["trace"]]],
  500, TestID -> "warm-start-local"];

VerificationTest[
  PureComplexMHChain[2, 4, "uniform", 10],
  $Failed, {PureComplexMHChain::target}, TestID -> "bad-target"];

VerificationTest[
  PureComplexMHChain[2, 4, "facet", 10, "kernel" -> "gibbs"],
  $Failed, {PureComplexMHChain::kernel}, TestID -> "bad-kernel"];

(* a caller's bare symbol option still matches the string option *)
VerificationTest[
  PureComplexMHChain[2, 4, "facet", 100, Global`thin -> 4, Global`verbose -> False]["thin"],
  4, TestID -> "symbol-option-name"];

VerificationTest[
  IntegratedAutocorrelationTime[ConstantArray[3, 50]],
  <|"tau" -> Infinity, "ess" -> 0|>, TestID -> "iact-constant"];

VerificationTest[
  SeedRandom[3];
  With[{a = IntegratedAutocorrelationTime[RandomReal[1, 20000]]}, a["tau"] < 0.6 && a["ess"] > 15000],
  True, TestID -> "iact-iid"];

VerificationTest[
  SeedRandom[5];
  With[{x = FoldList[0.9 #1 + #2 &, 0., RandomReal[NormalDistribution[], 50000]]},
    (* AR(1) with phi = 0.9: tau = (1 + phi)/(2 (1 - phi)) = 9.5 *)
    Abs[IntegratedAutocorrelationTime[x]["tau"] - 9.5] < 2],
  True, TestID -> "iact-ar1"];
