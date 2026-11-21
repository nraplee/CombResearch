(* sections/truth.wl
   Freezes what the scripts derive from the 9 exact truth WXFs
   p{p}q{q}_truth.wxf, (2,4) (2,5) (2,6) (2,7) (3,4) (3,5) (3,6) (4,4) (4,5):
     - per-n exact counts U, F = Sum q!/autF, V = Sum nV!/aut and their
       totals (truthCountsByN, src/validate_counts_vs_truth.wl);
     - stored totalFacetLabeled vs Sum q!/autF. They differ on the McKay
       cells (4,4) and (4,5): the McKay pipeline stores a different total,
       a FINDING kept as "totalFacetLabeledMatch" -> False;
     - per target the numV marginal in the float form the scripts use
       (marginalizeNumV over the stored pi, file order) and the exact
       rational marginal from weights nV!/aut, q!/autF, 1;
     - per target the truth-side stat marginal of every applicable stat
       (statKey-rounded keys, as in statMarginalL1, src/validate_mh_vs_truth.wl);
     - that p4q4_truth.wxf and p4q4_truth_mckay.wxf are identical. *)

(* from src/validate_mh_vs_truth.wl:89-90 at bd355d2 *)
truthPiKey = <|"vertex" -> "piVertex", "facet" -> "piFacet",
               "unlabeled" -> "piUnlabeled"|>;

(* from src/validate_mh_vs_truth.wl:95-100 at bd355d2 (marginalizeNumV) *)
truthMarginalizeNumV[truth_Association, target_String] := Module[
  {pi, numVs, pairs},
  pi = truth[truthPiKey[target]];
  numVs = #["stats"]["numV"] & /@ truth["complexes"];
  pairs = Thread[numVs -> pi];
  Merge[pairs, Total]];

(* from src/validate_mh_vs_truth.wl:180-181 at bd355d2 (statKey) *)
truthStatKey[v_?NumericQ] := Round[v, 10^-6];
truthStatKey[v_] := v;

(* Truth side of statMarginalL1, from src/validate_mh_vs_truth.wl:182-186
   at bd355d2 (pi, tv, tb exactly as there). *)
truthStatMarginal[truth_Association, target_String, name_String] := Module[{pi, tv},
  pi = truth[truthPiKey[target]];
  tv = truthStatKey[#["stats"][name]] & /@ truth["complexes"];
  Merge[Thread[tv -> pi], Total]];

(* from src/validate_counts_vs_truth.wl:45-50 at bd355d2 (truthCountsByN) *)
truthCountsByNGolden[truth_Association] := Module[{q = truth["q"], cs},
  cs = truth["complexes"];
  GroupBy[cs, #["nV"] &,
    <|"U" -> Length[#],
      "F" -> Total[(q! / #["autF"]) & /@ #],
      "V" -> Total[(#["nV"]! / #["aut"]) & /@ #]|> &]];

(* Exact rational numV marginal: class weights nV!/aut (vertex), q!/autF
   (facet), 1 (unlabeled), normalized. Same file order as the float form. *)
truthExactNumV[truth_Association, target_String] := Module[{q = truth["q"], cs, w},
  cs = truth["complexes"];
  w = Switch[target,
    "vertex", (#["nV"]! / #["aut"]) & /@ cs,
    "facet", (q! / #["autF"]) & /@ cs,
    "unlabeled", ConstantArray[1, Length[cs]]];
  Merge[Thread[(#["stats"]["numV"] & /@ cs) -> w], Total] / Total[w]];

truthCells = {{2, 4}, {2, 5}, {2, 6}, {2, 7}, {3, 4}, {3, 5}, {3, 6}, {4, 4}, {4, 5}};
truthTargets = {"vertex", "unlabeled", "facet"};
truthName[{p_, q_}] := "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth.wxf";

truthCellRecord[cell_] := Module[{truth, byN, sumF, statNames, rec},
  truth = goldenImport[truthName[cell]];
  byN = truthCountsByNGolden[truth];
  sumF = Total[Values[byN][[All, "F"]]];
  statNames = Keys[truth["complexes"][[1]]["stats"]];
  rec = <|
    "p" -> truth["p"], "q" -> truth["q"],
    "numIsoClasses" -> truth["numIsoClasses"],
    "numComplexes" -> Length[truth["complexes"]],
    "pipeline" -> Lookup[truth, "pipeline", Missing["NoPipelineKey"]],
    "countsByN" -> byN,
    "totals" -> <|"U" -> Total[Values[byN][[All, "U"]]], "F" -> sumF,
      "V" -> Total[Values[byN][[All, "V"]]]|>,
    "storedTotalFacetLabeled" -> truth["totalFacetLabeled"],
    "totalFacetLabeledMatch" -> (truth["totalFacetLabeled"] === sumF),
    "piTotals" -> AssociationMap[Total[truth[truthPiKey[#]]] &, truthTargets],
    "numVMarginalFloat" -> AssociationMap[truthMarginalizeNumV[truth, #] &, truthTargets],
    "numVMarginalExact" -> AssociationMap[truthExactNumV[truth, #] &, truthTargets],
    (* Stats that are "" for this p are skipped, as in
       src/validate_mh_vs_truth.wl:223-227 at bd355d2. Each marginal is
       stored as a rule list (Normal): statKey makes Rational keys, and an
       Association with Rational keys does not survive a WXF round trip in
       15.0.1 (lookups fail and === is False after Import). *)
    "statMarginalsFloat" -> AssociationMap[
      Function[t, Association @ Map[
        If[MatchQ[truth["complexes"][[1]]["stats"][#], ""], Nothing,
          # -> Normal[truthStatMarginal[truth, t, #]]] &, statNames]],
      truthTargets]|>;
  If[!rec["totalFacetLabeledMatch"],
    rec["totalFacetLabeledNote"] = "stored totalFacetLabeled differs from Sum q!/autF (" <>
      ToString[Lookup[truth, "pipeline", "cheap"]] <> " pipeline)"];
  goldenForget[truthName[cell]];
  rec];

goldenSection["truth"] := Module[{records},
  records = Association[
    (StringDrop[truthName[#], -4] -> truthCellRecord[#]) & /@ truthCells];
  records["p4q4_truth_vs_mckay"] = <|
    "identical" -> (goldenImport["p4q4_truth.wxf"] ===
      goldenImport["p4q4_truth_mckay.wxf"]),
    "hash" -> goldenHash[goldenImport["p4q4_truth_mckay.wxf"]]|>;
  <|"inputs" -> Append[truthName /@ truthCells, "p4q4_truth_mckay.wxf"],
    "records" -> records|>];
