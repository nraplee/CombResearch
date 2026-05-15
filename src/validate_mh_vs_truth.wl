(* validate_mh_vs_truth.wl
   Per (p, q) × target ∈ {unlabeled, facet, vertex}, compare the MH-sampled
   numV histogram against the exact π_target marginal on numV computed from
   the truth WXF. Reports per-bin probabilities, total-variation distance
   (L1/2), and a simple ASCII overlay.

   The MH WXF stores rows of 12 statistics per post-thin kept state, with
   numV in column 1. The truth WXF stores per-iso-class entries with
   "stats"["numV"] and three exact distributions piVertex, piFacet,
   piUnlabeled.

   Adapted from the (3,5) inline gate in run_mh_chains.wl
   (`truthVsMhNumVL1`), generalized over the three targets and the cells
   we have data for. Stat-other-than-numV extension is a future feature.

   Usage:
     wolframscript -file src/validate_mh_vs_truth.wl                # all cells × targets
     COMB_VAL_CELLS="3,3"                wolframscript -file ...
     COMB_VAL_CELLS="3,5"  COMB_VAL_TARGETS="vertex"  wolframscript -file ...
     COMB_VAL_TARGETS="unlabeled,facet"  wolframscript -file ...

   L1 alert threshold default 0.05. Override with COMB_VAL_THRESHOLD.
*)

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
dataDir = FileNameJoin[{projectRoot, "data"}];

defaultCells = {{3, 3}, {2, 4}, {2, 5}, {2, 6}, {3, 4}, {3, 5}};
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

Print["dataDir          = ", dataDir];
Print["resolvedCells    = ", resolvedCells];
Print["resolvedTargets  = ", resolvedTargets];
Print["L1 threshold     = ", threshold];
Print[""];

truthFile[p_, q_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth.wxf"}];
mhFile[p_, q_, t_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_mh_" <> t <> ".wxf"}];

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

validateCell[p_, q_, target_String] := Module[
  {tFile, mFile, truth, mh, truthBars, mhBars, cmp, l1Pass},
  tFile = truthFile[p, q];
  mFile = mhFile[p, q, target];
  If[!FileExistsQ[tFile],
    Print["  *** skip: no truth WXF at ", FileNameTake[tFile], " ***"];
    Return[$Failed]];
  If[!FileExistsQ[mFile],
    Print["  *** skip: no MH WXF at ", FileNameTake[mFile], " ***"];
    Return[$Failed]];
  truth = Import[tFile, "WXF"];
  mh = Import[mFile, "WXF"];
  truthBars = marginalizeNumV[truth, target];
  mhBars    = binMhNumV[mh];
  cmp = compareBins[truthBars, mhBars];
  l1Pass = cmp["l1"] < threshold;
  printOverlay["target=" <> target, cmp, l1Pass];
  <|"p" -> p, "q" -> q, "target" -> target,
    "l1" -> cmp["l1"], "pass" -> l1Pass|>];

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
  StringPadRight["L1",        12],
  "verdict"];
Do[
  Print["  ",
    StringPadRight["(" <> ToString[r["p"]] <> "," <>
                          ToString[r["q"]] <> ")", 10],
    StringPadRight[r["target"], 12],
    StringPadRight[ToString[NumberForm[r["l1"], {6, 4}]], 12],
    If[r["pass"], "PASS", "*** FAIL ***"]],
  {r, allResults}];

failCount = Count[allResults, r_ /; !r["pass"]];
Print[""];
Print["Total: ", Length[allResults], "  Failures: ", failCount];
If[failCount > 0, Print["At least one cell×target exceeded L1 threshold ",
  threshold, ". Investigate."]];
