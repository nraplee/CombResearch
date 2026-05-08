(* test_streaming_bliss.wl
   Correctness + speed validation for streaming_enumerator_bliss.wl
   (Option B). Compares against streaming_enumerator.wl's cheap-key
   pipeline on the five reachable cells.

   Validation gates (iso class counts must match):
     (2,4) -> 11   (2,5) -> 26   (2,6) -> 68
     (3,4) -> 66   (3,5) -> 445

   Run:
     wolframscript -file src/test_streaming_bliss.wl
   Restrict cells via env var:
     COMB_TEST_CELLS="2,4;3,4" wolframscript -file src/test_streaming_bliss.wl
*)

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator.wl"}]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator_bliss.wl"}]];

defaultCells = {{2, 4}, {2, 5}, {2, 6}, {3, 4}, {3, 5}};
expectedCounts = <|
  {2, 4} -> 11, {2, 5} -> 26, {2, 6} -> 68,
  {3, 4} -> 66, {3, 5} -> 445|>;

parseEnvCells[s_String] := Module[{pairs},
  pairs = StringSplit[StringTrim[s], ";"];
  pairs = StringSplit[#, ","] & /@ pairs;
  ToExpression /@ # & /@ pairs];

cells = Which[
  StringQ[Environment["COMB_TEST_CELLS"]] &&
    StringLength[Environment["COMB_TEST_CELLS"]] > 0,
    parseEnvCells[Environment["COMB_TEST_CELLS"]],
  True, defaultCells];

Print["Validation cells: ", cells];
Print["Expected counts:  ",
  Lookup[expectedCounts, Key[#], "?"] & /@ cells];
Print[""];

(* ============================================================
   Sanity tests on bipartiteIncidenceGraph + blissCanonicalKey
   ============================================================ *)

Print["----- canonical-key sanity checks -----"];

(* Two relabelings of the same complex must hash equal. *)
Module[{c1, c2, k1, k2},
  c1 = {{1, 2}, {2, 3}, {3, 4}};
  c2 = {{10, 20}, {20, 30}, {30, 40}};   (* same shape, relabeled *)
  k1 = blissCanonicalKey[c1];
  k2 = blissCanonicalKey[c2];
  Print["  iso pair (path 1-2-3-4 vs 10-20-30-40): ",
    If[k1 === k2, "MATCH ✓", "MISMATCH ✗"]];
  If[k1 =!= k2, Print["  *** FAIL ***"]; Abort[]]];

(* Two non-iso complexes must hash distinct. *)
Module[{path, matching, k1, k2},
  path     = {{1, 2}, {2, 3}, {3, 4}};   (* 3-edge path *)
  matching = {{1, 2}, {3, 4}, {5, 6}};   (* 3 disjoint edges *)
  k1 = blissCanonicalKey[path];
  k2 = blissCanonicalKey[matching];
  Print["  non-iso pair (path vs matching): ",
    If[k1 =!= k2, "DISTINCT ✓", "COLLISION ✗"]];
  If[k1 === k2, Print["  *** FAIL ***"]; Abort[]]];

Print[""];

(* ============================================================
   Per-cell comparison: cheap-key vs BLISS
   ============================================================ *)

Print["----- per-cell enumeration comparison -----"];
Print[StringJoin[Table["-", {78}]]];
Print[StringPadRight["cell", 10],
      StringPadRight["expected", 10],
      StringPadRight["cheap |iso|", 14],
      StringPadRight["bliss |iso|", 14],
      StringPadRight["cheap (s)", 12],
      StringPadRight["bliss (s)", 12],
      "speedup"];
Print[StringJoin[Table["-", {78}]]];

Do[
  Module[{p = cell[[1]], q = cell[[2]], expected,
          tCheap, rCheap, tBliss, rBliss, speedup, ok},
    expected = Lookup[expectedCounts, Key[cell], "?"];

    {tCheap, rCheap} = AbsoluteTiming[
      streamingEnumeratePure[p, q, Parallel -> True]];
    {tBliss, rBliss} = AbsoluteTiming[
      streamingEnumeratePureBLISS[p, q, Parallel -> True]];

    speedup = If[tBliss > 0, tCheap / tBliss, 0];
    ok = (Length[rCheap["isoReps"]] === Length[rBliss["isoReps"]]) &&
         (expected === "?" || Length[rBliss["isoReps"]] === expected);

    Print[
      StringPadRight["(" <> ToString[p] <> "," <> ToString[q] <> ")", 10],
      StringPadRight[ToString[expected], 10],
      StringPadRight[ToString[Length[rCheap["isoReps"]]], 14],
      StringPadRight[ToString[Length[rBliss["isoReps"]]], 14],
      StringPadRight[ToString[NumberForm[tCheap, {7, 2}]], 12],
      StringPadRight[ToString[NumberForm[tBliss, {7, 2}]], 12],
      ToString[NumberForm[speedup, {6, 2}]], "x ",
      If[ok, "✓", "*** MISMATCH ***"]];
    If[!ok, Abort[]]],
  {cell, cells}];

Print[StringJoin[Table["-", {78}]]];
Print["all gates pass."];
