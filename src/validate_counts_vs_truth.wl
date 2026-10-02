(* validate_counts_vs_truth.wl
   Cross-check ECGrav's exact counters against our enumerated truth, per
   (p, q) cell and per vertex count n. All comparisons are exact integers.

     NumUnlabeledPureComplexes[p,q,n]     vs  #{iso classes X : nV(X) = n}
     NumFacetLabeledPureComplexes[p,q,n]  vs  Σ_{nV(X)=n} q!/autF(X)
     NumVertexLabeledPureComplexes[p,q,n] vs  Σ_{nV(X)=n} n!/aut(X)

   These are the normalizers of π_U, π_F, π_V in enumerate_truth.wl, so a
   match here means ECGrav and we agree on what each ensemble IS before
   any sampler is tested. A mismatch in the facet column would point at a
   definitional difference in autF.

   Also prints the q=10 totals (no truth there) for reference.

   Usage:
     wolframscript -file src/validate_counts_vs_truth.wl
     COMB_VAL_CELLS="4,5" wolframscript -file src/validate_counts_vs_truth.wl
*)

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
dataDir = FileNameJoin[{projectRoot, "data"}];

Get[FileNameJoin[{scriptDir, "load_ecgrav.wl"}]];

defaultCells = {{2, 4}, {2, 5}, {2, 6}, {2, 7},
                {3, 4}, {3, 5}, {3, 6},
                {4, 4}, {4, 5}};

parseEnvCells[s_String] := Module[{pairs},
  pairs = StringSplit[StringTrim[s], ";"];
  pairs = StringSplit[#, ","] & /@ pairs;
  ToExpression /@ # & /@ pairs];

resolvedCells = With[{e = Environment["COMB_VAL_CELLS"]},
  If[StringQ[e] && StringLength[e] > 0, parseEnvCells[e], defaultCells]];

truthFile[p_, q_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth.wxf"}];

(* Per-n exact counts from a truth payload. *)
truthCountsByN[truth_Association] := Module[{q = truth["q"], cs},
  cs = truth["complexes"];
  GroupBy[cs, #["nV"] &,
    <|"U" -> Length[#],
      "F" -> Total[(q! / #["autF"]) & /@ #],
      "V" -> Total[(#["nV"]! / #["aut"]) & /@ #]|> &]];

checkCell[p_, q_] := Module[{tf, truth, byN, ns, rows, allOK},
  tf = truthFile[p, q];
  If[!FileExistsQ[tf],
    Print["  *** skip: no truth at ", FileNameTake[tf], " ***"];
    Return[$Failed]];
  truth = Import[tf, "WXF"];
  byN = truthCountsByN[truth];
  ns = Range[p, p q];
  rows = Table[
    With[{t = Lookup[byN, n, <|"U" -> 0, "F" -> 0, "V" -> 0|>],
          e = <|"U" -> NumUnlabeledPureComplexes[p, q, n],
                "F" -> NumFacetLabeledPureComplexes[p, q, n],
                "V" -> NumVertexLabeledPureComplexes[p, q, n]|>},
      <|"n" -> n, "truth" -> t, "ecg" -> e,
        "ok" -> AllTrue[{"U", "F", "V"}, t[#] === e[#] &]|>],
    {n, ns}];
  rows = Select[rows, #["truth"]["U"] > 0 || #["ecg"]["U"] > 0 &];
  Print["  ", StringPadRight["n", 5],
    StringPadRight["U truth/ecg", 22],
    StringPadRight["F truth/ecg", 34],
    StringPadRight["V truth/ecg", 40], "ok"];
  Do[
    Print["  ", StringPadRight[ToString[r["n"]], 5],
      StringPadRight[ToString[r["truth"]["U"]] <> "/" <>
        ToString[r["ecg"]["U"]], 22],
      StringPadRight[ToString[r["truth"]["F"]] <> "/" <>
        ToString[r["ecg"]["F"]], 34],
      StringPadRight[ToString[r["truth"]["V"]] <> "/" <>
        ToString[r["ecg"]["V"]], 40],
      If[r["ok"], "ok", "*** MISMATCH ***"]],
    {r, rows}];
  allOK = AllTrue[rows, #["ok"] &];
  <|"p" -> p, "q" -> q, "ok" -> allOK,
    "isoTruth" -> truth["numIsoClasses"],
    "isoECGrav" -> NumUnlabeledPureComplexes[p, q]|>];

results = {};
Do[
  Print["========================================"];
  Print["cell (", cell[[1]], ", ", cell[[2]], ")"];
  With[{r = checkCell @@ cell},
    If[AssociationQ[r], AppendTo[results, r]]],
  {cell, resolvedCells}];

Print["========================================"];
Print["SUMMARY  (ECGrav ", $CombECGravVersion, ")"];
Print["========================================"];
Do[
  Print["  (", r["p"], ",", r["q"], ")  iso truth = ", r["isoTruth"],
    "  ECGrav = ", r["isoECGrav"], "   per-n U/F/V: ",
    If[r["ok"], "ALL MATCH", "*** MISMATCH ***"]],
  {r, results}];
Print["Total: ", Length[results], "  Mismatches: ",
  Count[results, r_ /; !r["ok"]]];

Print[""];
Print["q=10 totals (no truth; reference only):"];
Do[
  Print["  p=", p, "  U=", NumUnlabeledPureComplexes[p, 10],
    "  F=", NumFacetLabeledPureComplexes[p, 10],
    "  V=", NumVertexLabeledPureComplexes[p, 10]],
  {p, {2, 3, 4}}];
