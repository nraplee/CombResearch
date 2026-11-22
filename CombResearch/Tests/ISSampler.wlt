(* ::Package:: *)

(* Tests for ISSampler.wl: the weight formulas, the 15-column layout, seed
   reproducibility, and that reweighted samples at (2,4) reproduce the exact
   numV marginal of each target (computed here from the enumerator). Run with
   Tests/run_tests.wl (about 1 min). *)

If[!MemberQ[$Packages, "CombResearch`"],
  Get[FileNameJoin[{If[ValueQ[$CombResearchTestRoot], $CombResearchTestRoot,
    ParentDirectory[DirectoryName[$InputFileName]]], "Tests", "TestPrelude.wl"}]]];

VerificationTest[
  $PureComplexISNames,
  Join[$PureComplexStatisticNames, {"wVertex", "wUnlabeled", "wFacet"}],
  TestID -> "names-15"];

(* row {numV = 4, aut = 8, autF = 2, ...} at q = 4:
   wU = 8/4! = 1/3, wF = 8 4!/(2 4!) = 4 *)
VerificationTest[
  PureComplexISWeights[{{4, 8, 2, 1, 1, 1, 1., "", "", 1, "", ""}}, 4],
  {{4, 8, 2, 1, 1, 1, 1., "", "", 1, "", "", 1, 1/3, 4}},
  TestID -> "weights-formula"];

VerificationTest[
  Module[{a, b},
    SeedRandom[99]; a = PureComplexISSample[{2, 4}, 50];
    SeedRandom[99]; b = PureComplexISSample[{2, 4}, 50];
    {a === b, Length[a["rows"]], Union[Length /@ a["rows"]], Length[a["complexes"]]}],
  {True, 50, {15}, 50}, TestID -> "seeded-layout"];

VerificationTest[
  SeedRandom[5];
  With[{r = PureComplexISSample[{3, 4}, 30]},
    r["rows"][[All, ;; 12]] === (PureComplexStatistics[#, 3] & /@ r["complexes"])],
  True, TestID -> "rows-are-statistics"];

VerificationTest[
  SeedRandom[6];
  Union[PureComplexISSample[{2, 5, 5}, 40]["rows"][[All, 1]]],
  {5}, TestID -> "fixed-numV"];

VerificationTest[EffectiveSampleSize[{1, 1, 1, 1}], 4., TestID -> "ess-flat"];
VerificationTest[EffectiveSampleSize[{1, 0, 0, 0}], 1., TestID -> "ess-one"];
VerificationTest[EffectiveSampleSize[{0, 0}], 0, TestID -> "ess-zero"];

(* reweighted numV marginal at (2,4) vs the exact one, per target *)
isTestExact[p_, q_, target_] := Module[{reps, st, w},
  reps = EnumerateUnlabeledPureComplexes[p, q, Method -> "Cheap", "Parallel" -> False]["isoReps"];
  st = AssociationThread[$PureComplexStatisticNames -> PureComplexStatistics[#, p]] & /@ reps;
  w = Switch[target,
    "unlabeled", ConstantArray[1, Length[reps]],
    "facet", (q! / #["autF"]) & /@ st,
    "vertex", (#["numV"]! / #["aut"]) & /@ st];
  N[Merge[Thread[(#["numV"] & /@ st) -> w], Total] / Total[w]]];

(* The bound scales with the effective sample size: about 3x the expected L1
   of an unbiased estimate, Sum sqrt(pi (1 - pi) / ESS) over the numV bins.
   (Unlabeled and facet weights leave ESS ~ N/5 at (2,4).) *)
SeedRandom[2024];
isTestRows = PureComplexISSample[{2, 4}, 20000]["rows"];

Do[With[{t = target, col = <|"vertex" -> 13, "unlabeled" -> 14, "facet" -> 15|>[target]},
    VerificationTest[
      Module[{w = N[isTestRows[[All, col]]], est, ex, ks, l1, bound},
        est = Merge[Thread[isTestRows[[All, 1]] -> w], Total] / Total[w];
        ex = isTestExact[2, 4, t];
        ks = Union[Keys[est], Keys[ex]];
        l1 = Total[Abs[Lookup[est, ks, 0] - Lookup[ex, ks, 0]]];
        bound = 3 Total[Sqrt[# (1 - #) / EffectiveSampleSize[w]] & /@ Values[ex]];
        l1 < bound],
      True, TestID -> "reweighted-numV-24-" <> t]],
  {target, {"vertex", "unlabeled", "facet"}}];
