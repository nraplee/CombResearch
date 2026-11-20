(* validate_mh_vs_truth.wl
   Per (p, q) × target ∈ {unlabeled, facet, vertex}, compare the MH-sampled
   numV histogram against the exact π_target marginal on numV computed from
   the truth WXF. Reports per-bin probabilities, L1 distance, and a simple
   ASCII overlay.

   The MH WXF stores rows of 12 statistics per post-thin kept state, with
   numV in column 1. The truth WXF stores per-iso-class entries with
   "stats"["numV"] and three exact distributions piVertex, piFacet,
   piUnlabeled.

   Adapted from the (3,5) inline gate in run_mh_chains.wl
   (`truthVsMhNumVL1`), generalized over the three targets and the cells
   we have data for. Stat-other-than-numV extension is a future feature.

   Usage:
     wolframscript -file src/validate_mh_vs_truth.wl                # default grid × targets
     COMB_VAL_CELLS="3,3"                wolframscript -file ...
     COMB_VAL_CELLS="3,5"  COMB_VAL_TARGETS="vertex"  wolframscript -file ...
     COMB_VAL_TARGETS="unlabeled,facet"  wolframscript -file ...

   L1 alert threshold default 0.05. Override with COMB_VAL_THRESHOLD.

   Sample source (added 2026-09-25 for the ECGrav 1.17 campaign):
     COMB_VAL_SOURCE=mh           data/p{p}q{q}_mh_{target}.wxf   (default)
     COMB_VAL_SOURCE=ecgexact     data/p{p}q{q}_ecgexact_{target}.wxf
     COMB_VAL_SOURCE=ecgmcmc      data/p{p}q{q}_ecgmcmc_{target}.wxf
     COMB_VAL_SOURCE=ecglegacyfacet   negative control (must FAIL)
   (the ecg* files come from src/run_ecgrav_samplers.wl)

   Extra diagnostics beyond the numV L1:
     - iid p-value of the observed numV L1: fraction of multinomial
       resamples of size N from the truth marginal whose L1 is >= the
       observed one. Only meaningful for independent draws (ecgexact;
       roughly for ecgmcmc, whose draws are corrT sweeps apart). MH rows
       are autocorrelated, so a low value there is expected.
     - per-iso-class Pearson chi-square, when the payload carries
       "classIdx" (ecg* sources): classes pooled in order of expected
       count until each bin has E >= 5. Also the count of samples that
       matched no truth class (must be 0).
     - L1 of every other stat marginal; the worst one is reported.
   A run is written to data/validation_{source}_summary.wxf.
*)

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
Get[FileNameJoin[{scriptDir, "comb_paths.wl"}]];
dataDir = $CombDataDir;

defaultCells = {{2, 4}, {2, 5}, {2, 6}, {2, 7},
                {3, 4}, {3, 5}, {3, 6},
                {4, 4}, {4, 5}};
defaultTargets = {"unlabeled", "facet", "vertex"};

parseEnvCells[s_String] := Module[{pairs},
  pairs = StringSplit[StringTrim[s], ";"];
  pairs = StringSplit[#, ","] & /@ pairs;
  ToExpression /@ # & /@ pairs];

parseEnvList[s_String] := StringTrim /@ StringSplit[StringTrim[s], ","];

resolvedCells = With[{e = Environment["COMB_VAL_CELLS"]},
  If[StringQ[e] && StringLength[e] > 0, parseEnvCells[e], defaultCells]];

resolvedTargets = With[{e = Environment["COMB_VAL_TARGETS"]},
  If[StringQ[e] && StringLength[e] > 0, parseEnvList[e], defaultTargets]];

threshold = With[{e = Environment["COMB_VAL_THRESHOLD"]},
  If[StringQ[e] && StringLength[e] > 0, ToExpression[e], 0.05]];

source = With[{e = Environment["COMB_VAL_SOURCE"]},
  If[StringQ[e] && StringLength[e] > 0, e, "mh"]];

Print["dataDir          = ", dataDir];
Print["resolvedCells    = ", resolvedCells];
Print["resolvedTargets  = ", resolvedTargets];
Print["L1 threshold     = ", threshold];
Print["source           = ", source];
Print[""];

truthFile[p_, q_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth.wxf"}];
mhFile[p_, q_, t_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_" <> source <> "_" <> t <> ".wxf"}];

(* Map target name -> truth Association key holding the exact π over iso
   classes. *)
piKey = <|"vertex" -> "piVertex", "facet" -> "piFacet",
          "unlabeled" -> "piUnlabeled"|>;

(* Marginalize an iso-class distribution onto numV: group iso classes by
   their numV value and sum probabilities. Returns Association
   numV -> probability. *)
marginalizeNumV[truth_Association, target_String] := Module[
  {pi, numVs, pairs},
  pi = truth[piKey[target]];
  numVs = #["stats"]["numV"] & /@ truth["complexes"];
  pairs = Thread[numVs -> pi];
  Merge[pairs, Total]];

(* Bin the MH numV column (column 1) into an empirical Association
   numV -> probability. *)
binMhNumV[mh_Association] := Module[{numVs, validVals},
  numVs = mh["rows"][[All, 1]];
  validVals = Select[numVs, NumericQ];
  If[Length[validVals] == 0, Return[<||>]];
  N[Counts[validVals] / Length[validVals]]];

(* Align two Associations on the union of keys and compute |a-b| per
   bin, plus total L1. *)
compareBins[truthBars_Association, mhBars_Association] := Module[
  {keys, tv, mv, diffs, l1},
  keys = Sort @ Union[Keys[truthBars], Keys[mhBars]];
  tv = Lookup[truthBars, #, 0.] & /@ keys;
  mv = Lookup[mhBars,    #, 0.] & /@ keys;
  diffs = Abs[tv - mv];
  l1 = Total[diffs];
  <|"keys" -> keys, "truth" -> tv, "mh" -> mv, "diff" -> diffs,
    "l1" -> l1|>];

(* ASCII bar at scale = 40 chars per unit probability. *)
asciiBar[p_, scale_:40] := StringJoin @ ConstantArray["#", Round[p * scale]];

printOverlay[label_String, cmp_Association, l1Pass_] := Module[
  {keys, truth, mh, diffs},
  keys = cmp["keys"]; truth = cmp["truth"]; mh = cmp["mh"]; diffs = cmp["diff"];
  Print["  ", label,
    "  L1 = ", NumberForm[cmp["l1"], {6, 4}],
    "   ", If[l1Pass, "PASS (<", "FAIL (≥"], threshold, ")"];
  Print["    ",
    StringPadRight["numV", 6],
    StringPadRight["truth", 12],
    StringPadRight["mh", 12],
    "diff       overlay (T=., M=#)"];
  MapThread[
    Function[{k, t, m, d},
      Print["    ",
        StringPadRight[ToString[k], 6],
        StringPadRight[ToString[NumberForm[t, {6, 4}]], 12],
        StringPadRight[ToString[NumberForm[m, {6, 4}]], 12],
        StringPadRight[ToString[NumberForm[d, {5, 4}]], 11],
        StringPadRight[asciiBar[t, 30], 30, "."],
        " | ", asciiBar[m, 30]]],
    {keys, truth, mh, diffs}]];

(* Monte Carlo p-value of an observed L1 under iid sampling of size n
   from the discrete distribution `bars` (Association value -> prob). *)
iidL1PValue[bars_Association, n_Integer, l1Obs_, reps_:400] := Module[
  {pv = Values[bars], sims},
  pv = pv / Total[pv];
  sims = Table[
    Total @ Abs[RandomVariate[MultinomialDistribution[n, pv]] / N[n] - pv],
    {reps}];
  N[Count[sims, x_ /; x >= l1Obs] / reps]];

(* Pearson chi-square on iso classes, pooling classes (sorted by expected
   count) until every bin has E >= 5. Returns chi2, df, p-value. *)
classChiSquare[pi_List, classIdx_List] := Module[
  {n, obs, exp, ord, bins = {}, curO = 0, curE = 0., chi2, df},
  n = Count[classIdx, i_ /; i > 0];
  obs = Lookup[Counts[classIdx], Range[Length[pi]], 0];
  exp = n pi;
  ord = Ordering[exp];
  Do[
    curO += obs[[i]]; curE += exp[[i]];
    If[curE >= 5, AppendTo[bins, {curO, curE}]; curO = 0; curE = 0.],
    {i, ord}];
  If[curE > 0 && bins =!= {},
    bins[[-1]] += {curO, curE}];
  If[Length[bins] < 2, Return[<|"chi2" -> 0., "df" -> 0, "pValue" -> 1.,
    "bins" -> Length[bins]|>]];
  chi2 = Total[(#[[1]] - #[[2]])^2 / #[[2]] & /@ bins];
  df = Length[bins] - 1;
  <|"chi2" -> chi2, "df" -> df, "bins" -> Length[bins],
    "pValue" -> 1. - CDF[ChiSquareDistribution[df], chi2]|>];

(* L1 between the truth marginal and the sample marginal of stat column j.
   Values rounded so float stats (largestCompRatio) bin identically. *)
statKey[v_?NumericQ] := Round[v, 10^-6];
statKey[v_] := v;
statMarginalL1[truth_Association, target_String, rows_List, j_Integer,
               name_String] := Module[{pi, tv, sv, tb, sb},
  pi = truth[piKey[target]];
  tv = statKey[#["stats"][name]] & /@ truth["complexes"];
  tb = Merge[Thread[tv -> pi], Total];
  sv = statKey /@ rows[[All, j]];
  sb = N[Counts[sv] / Length[sv]];
  compareBins[tb, sb]["l1"]];

missingInputs = {};

validateCell[p_, q_, target_String] := Module[
  {tFile, mFile, truth, mh, truthBars, mhBars, cmp, l1Pass,
   nRows, iidP, cls = Missing["NoClassIdx"], unmatched = Missing[],
   otherL1, worst},
  tFile = truthFile[p, q];
  mFile = mhFile[p, q, target];
  If[!FileExistsQ[tFile],
    Print["  *** skip: no truth WXF at ", FileNameTake[tFile], " ***"];
    AppendTo[missingInputs, tFile];
    Return[$Failed]];
  If[!FileExistsQ[mFile],
    Print["  *** skip: no MH WXF at ", FileNameTake[mFile], " ***"];
    AppendTo[missingInputs, mFile];
    Return[$Failed]];
  truth = Import[tFile, "WXF"];
  mh = Import[mFile, "WXF"];
  truthBars = marginalizeNumV[truth, target];
  mhBars    = binMhNumV[mh];
  cmp = compareBins[truthBars, mhBars];
  l1Pass = cmp["l1"] < threshold;
  printOverlay["target=" <> target, cmp, l1Pass];
  nRows = Length[mh["rows"]];
  iidP = iidL1PValue[truthBars, nRows, cmp["l1"]];
  Print["    N = ", nRows, "   iid p-value of numV L1 = ", iidP];
  If[ListQ[mh["classIdx"]],
    unmatched = Count[mh["classIdx"], 0];
    cls = classChiSquare[truth[piKey[target]], mh["classIdx"]];
    Print["    per-class chi2 = ", NumberForm[cls["chi2"], {8, 2}],
      "  df = ", cls["df"], "  p = ", NumberForm[cls["pValue"], {5, 4}],
      "   unmatched samples = ", unmatched]];
  otherL1 = Association @ Table[
    With[{name = mh["headers"][[j]]},
      If[MatchQ[truth["complexes"][[1]]["stats"][name], ""], Nothing,
        name -> statMarginalL1[truth, target, mh["rows"], j, name]]],
    {j, 2, Length[mh["headers"]]}];
  worst = First @ Keys @ TakeLargest[otherL1, 1];
  Print["    other stats: worst L1 = ", NumberForm[otherL1[worst], {6, 4}],
    " (", worst, ")"];
  <|"p" -> p, "q" -> q, "target" -> target, "source" -> source,
    "n" -> nRows, "l1" -> cmp["l1"], "pass" -> l1Pass,
    "iidPValue" -> iidP, "classChi2" -> cls, "unmatched" -> unmatched,
    "otherStatL1" -> otherL1|>];

(* ===== Driver ===== *)
allResults = {};
Do[
  Module[{p = cell[[1]], q = cell[[2]]},
    Print["========================================"];
    Print["cell (", p, ", ", q, ")"];
    Print["========================================"];
    Do[
      Module[{r},
        r = validateCell[p, q, target];
        If[AssociationQ[r], AppendTo[allResults, r]];
        Print[""]],
      {target, resolvedTargets}]],
  {cell, resolvedCells}];

(* ===== Summary table ===== *)
Print["========================================"];
Print["SUMMARY"];
Print["========================================"];
Print["  ",
  StringPadRight["cell",      10],
  StringPadRight["target",    12],
  StringPadRight["L1",        10],
  StringPadRight["iid p",     8],
  StringPadRight["class p",   10],
  StringPadRight["worst other", 26],
  "verdict"];
Do[
  Print["  ",
    StringPadRight["(" <> ToString[r["p"]] <> "," <>
                          ToString[r["q"]] <> ")", 10],
    StringPadRight[r["target"], 12],
    StringPadRight[ToString[NumberForm[r["l1"], {6, 4}]], 10],
    StringPadRight[ToString[NumberForm[r["iidPValue"], {4, 3}]], 8],
    StringPadRight[If[AssociationQ[r["classChi2"]],
      ToString[NumberForm[r["classChi2"]["pValue"], {4, 3}]], "-"], 10],
    StringPadRight[With[{w = First @ Keys @ TakeLargest[r["otherStatL1"], 1]},
      ToString[NumberForm[r["otherStatL1"][w], {5, 4}]] <> " " <> w], 26],
    If[r["pass"], "PASS", "*** FAIL ***"]],
  {r, allResults}];

failCount = Count[allResults, r_ /; !r["pass"]];
Print[""];
Print["Total: ", Length[allResults], "  Failures: ", failCount];
If[failCount > 0, Print["At least one cell×target exceeded L1 threshold ",
  threshold, ". Investigate."]];
If[missingInputs =!= {},
  missingInputs = DeleteDuplicates[missingInputs];
  Print["*** ", Length[missingInputs], " input file(s) missing in ", dataDir,
    "; those cell x target combinations were NOT validated:"];
  Scan[Print["      ", FileNameTake[#]] &, missingInputs];
  Print["    Truth: wolframscript -file src/enumerate_truth.wl (COMB_TRUTH_CELLS)"];
  Print["    Samples: src/run_mh_chains.wl (source mh) or src/run_ecgrav_samplers.wl (COMB_ECG_SAMPLER)"]];

(* Nothing validated (all inputs missing): keep any existing summary. *)
If[allResults =!= {},
  Export[FileNameJoin[{dataDir, "validation_" <> source <> "_summary.wxf"}],
    <|"source" -> source, "threshold" -> threshold, "results" -> allResults,
      "createdAt" -> DateString[]|>, "WXF"]];
