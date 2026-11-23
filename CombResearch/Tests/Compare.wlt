(* ::Package:: *)

(* Tests for Compare.wl: truth marginals, sample histograms, L1, the iid
   p-value, the per-class chi-square, and the IS statistic histograms. Run
   with Tests/run_tests.wl (well under a minute). *)

If[!MemberQ[$Packages, "CombResearch`"],
  Get[FileNameJoin[{If[ValueQ[$CombResearchTestRoot], $CombResearchTestRoot,
    ParentDirectory[DirectoryName[$InputFileName]]], "Tests", "TestPrelude.wl"}]]];

cmpTestTruth = <|
  "complexes" -> {<|"stats" -> <|"numV" -> 3, "aut" -> 6|>|>,
                  <|"stats" -> <|"numV" -> 4, "aut" -> 2|>|>,
                  <|"stats" -> <|"numV" -> 3, "aut" -> 2|>|>},
  "piUnlabeled" -> {1/3, 1/3, 1/3}, "piVertex" -> {1/10, 6/10, 3/10},
  "piFacet" -> {1/2, 1/4, 1/4}|>;

VerificationTest[PureComplexTruthMarginal[cmpTestTruth, "unlabeled"],
  <|3 -> 2/3, 4 -> 1/3|>, TestID -> "truth-marginal-numV"];
VerificationTest[PureComplexTruthMarginal[cmpTestTruth, "vertex", "aut"],
  <|6 -> 1/10, 2 -> 9/10|>, TestID -> "truth-marginal-stat"];

VerificationTest[SampleHistogram[{2, 1, 2, ""}], <|1 -> 1/3., 2 -> 2/3.|>,
  TestID -> "hist-unweighted"];
VerificationTest[SampleHistogram[{}], <||>, TestID -> "hist-empty"];
VerificationTest[SampleHistogram[{2, 1, 2}, {1., 2., 1.}], <|1 -> 0.5, 2 -> 0.5|>,
  TestID -> "hist-weighted"];

VerificationTest[HistogramL1Distance[<|1 -> 0.5, 2 -> 0.5|>, <|2 -> 1.|>], 1.,
  TestID -> "l1-union"];
VerificationTest[HistogramL1Distance[<|1 -> 1/2, 2 -> 1/2|>, <|2 -> 0.5, 1 -> 0.5|>], 0.,
  TestID -> "l1-zero"];

VerificationTest[SeedRandom[1]; IIDL1PValue[<|1 -> 0.5, 2 -> 0.5|>, 100, 0.], 1.,
  TestID -> "iid-p-zero-l1"];
VerificationTest[SeedRandom[1]; IIDL1PValue[<|1 -> 0.5, 2 -> 0.5|>, 1000, 0.5,
    "Replicates" -> 50], 0., TestID -> "iid-p-large-l1"];

VerificationTest[
  With[{c = IsoClassChiSquare[{1/4, 1/4, 1/2}, Join[ConstantArray[1, 25],
      ConstantArray[2, 25], ConstantArray[3, 50]]]},
    {Sort[Keys[c]], c["chi2"], c["df"], c["pValue"]}],
  {{"bins", "chi2", "df", "pValue"}, 0., 2, 1.}, TestID -> "chi2-exact-fit"];

(* IS statistic histograms from a small (2,4) sample *)
SeedRandom[11];
cmpTestRows = PureComplexISSample[{2, 4}, 400]["rows"];
cmpTestHists = PureComplexStatisticHistograms[$PureComplexISNames, cmpTestRows];

VerificationTest[
  {cmpTestHists["sourceN"], cmpTestHists["filters"], cmpTestHists["targets"],
   cmpTestHists["statistics"] === $PureComplexStatisticNames},
  {400, {"all", "connected"}, {"vertex", "unlabeled", "facet"}, True},
  TestID -> "stathists-layout"];

VerificationTest[
  cmpTestHists["hists"]["numV"]["all"]["unlabeled"] ===
    SampleHistogram[cmpTestRows[[All, 1]], N[cmpTestRows[[All, 14]]]],
  True, TestID -> "stathists-numV-is-weighted-hist"];

VerificationTest[
  cmpTestHists["n"]["connected"] == Count[cmpTestRows[[All, 4]], 1] &&
    cmpTestHists["hists"]["connected"]["connected"]["vertex"] === <|1 -> 1.|>,
  True, TestID -> "stathists-connected-filter"];

VerificationTest[
  AllTrue[Flatten[Values /@ Values /@ Values[cmpTestHists["hists"]]],
    # === <||> || Abs[Total[#] - 1] < 10^-12 &],
  True, TestID -> "stathists-normalized"];

VerificationTest[
  cmpTestHists["ESS"]["all"]["vertex"] == 400. &&
    cmpTestHists["ESS"]["all"]["facet"] == EffectiveSampleSize[N[cmpTestRows[[All, 15]]]],
  True, TestID -> "stathists-ess"];
