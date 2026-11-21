(* tests/golden/lib/validate.wl
   Verbatim copies of the numV / class / other-stat comparison helpers of
   src/validate_mh_vs_truth.wl, used by tests/golden/sections/validate.wl.
   Only the inputs change: data comes through goldenImport, and the global
   `source`/`threshold` of the script become arguments. Nothing here prints,
   draws random numbers (iidL1PValue, l.149-155, is left out: it has no
   seed) or writes files. *)

(* from src/validate_mh_vs_truth.wl:51-54 at bd355d2 *)
valDefaultCells = {{2, 4}, {2, 5}, {2, 6}, {2, 7},
                   {3, 4}, {3, 5}, {3, 6},
                   {4, 4}, {4, 5}};
valDefaultTargets = {"unlabeled", "facet", "vertex"};
(* from src/validate_mh_vs_truth.wl:69-70 at bd355d2 (env default) *)
valThreshold = 0.05;

(* from src/validate_mh_vs_truth.wl:82-85 at bd355d2, as store-relative names *)
valTruthName[p_, q_] := "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth.wxf";
valSampleName[source_, p_, q_, t_] :=
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_" <> source <> "_" <> t <> ".wxf";

(* from src/validate_mh_vs_truth.wl:89-90 at bd355d2 *)
valPiKey = <|"vertex" -> "piVertex", "facet" -> "piFacet",
             "unlabeled" -> "piUnlabeled"|>;

(* from src/validate_mh_vs_truth.wl:95-100 at bd355d2 *)
valMarginalizeNumV[truth_Association, target_String] := Module[
  {pi, numVs, pairs},
  pi = truth[valPiKey[target]];
  numVs = #["stats"]["numV"] & /@ truth["complexes"];
  pairs = Thread[numVs -> pi];
  Merge[pairs, Total]];

(* from src/validate_mh_vs_truth.wl:104-108 at bd355d2 *)
valBinMhNumV[mh_Association] := Module[{numVs, validVals},
  numVs = mh["rows"][[All, 1]];
  validVals = Select[numVs, NumericQ];
  If[Length[validVals] == 0, Return[<||>]];
  N[Counts[validVals] / Length[validVals]]];

(* from src/validate_mh_vs_truth.wl:112-120 at bd355d2 *)
valCompareBins[truthBars_Association, mhBars_Association] := Module[
  {keys, tv, mv, diffs, l1},
  keys = Sort @ Union[Keys[truthBars], Keys[mhBars]];
  tv = Lookup[truthBars, #, 0.] & /@ keys;
  mv = Lookup[mhBars,    #, 0.] & /@ keys;
  diffs = Abs[tv - mv];
  l1 = Total[diffs];
  <|"keys" -> keys, "truth" -> tv, "mh" -> mv, "diff" -> diffs,
    "l1" -> l1|>];

(* from src/validate_mh_vs_truth.wl:159-176 at bd355d2 *)
valClassChiSquare[pi_List, classIdx_List] := Module[
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

(* from src/validate_mh_vs_truth.wl:180-189 at bd355d2 *)
valStatKey[v_?NumericQ] := Round[v, 10^-6];
valStatKey[v_] := v;
valStatMarginalL1[truth_Association, target_String, rows_List, j_Integer,
                  name_String] := Module[{pi, tv, sv, tb, sb},
  pi = truth[valPiKey[target]];
  tv = valStatKey[#["stats"][name]] & /@ truth["complexes"];
  tb = Merge[Thread[tv -> pi], Total];
  sv = valStatKey /@ rows[[All, j]];
  sb = N[Counts[sv] / Length[sv]];
  valCompareBins[tb, sb]["l1"]];

(* validateCell, from src/validate_mh_vs_truth.wl:193-234 at bd355d2, minus
   printing and iidPValue. Same operation order. "cmp" carries the
   compareBins vectors (its "mh" entry is the sample marginal). *)
valCell[source_String, p_, q_, target_String] := Module[
  {truth, mh, truthBars, mhBars, cmp, l1Pass, nRows,
   cls = Missing["NoClassIdx"], unmatched = Missing[], otherL1},
  truth = goldenImport[valTruthName[p, q]];
  mh = goldenImport[valSampleName[source, p, q, target]];
  truthBars = valMarginalizeNumV[truth, target];
  mhBars    = valBinMhNumV[mh];
  cmp = valCompareBins[truthBars, mhBars];
  l1Pass = cmp["l1"] < valThreshold;
  nRows = Length[mh["rows"]];
  If[ListQ[mh["classIdx"]],
    unmatched = Count[mh["classIdx"], 0];
    cls = valClassChiSquare[truth[valPiKey[target]], mh["classIdx"]]];
  otherL1 = Association @ Table[
    With[{name = mh["headers"][[j]]},
      If[MatchQ[truth["complexes"][[1]]["stats"][name], ""], Nothing,
        name -> valStatMarginalL1[truth, target, mh["rows"], j, name]]],
    {j, 2, Length[mh["headers"]]}];
  goldenForget[valSampleName[source, p, q, target]];
  <|"p" -> p, "q" -> q, "target" -> target, "source" -> source,
    "n" -> nRows, "l1" -> cmp["l1"], "pass" -> l1Pass,
    "classChi2" -> cls, "unmatched" -> unmatched,
    "otherStatL1" -> otherL1, "cmp" -> cmp|>];
