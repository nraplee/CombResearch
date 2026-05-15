(* test_streaming_mckay.wl
   Phase 4b step 1+2 (per docs/PLAN_TRUTH_ENUMERATION.md alternative D and
   the Phase 4 plan file): profile and validate the three streaming
   enumerators sequentially. Sequential mode chosen to get clean
   per-kernel memory peaks free of subkernel overhead. Establishes the
   baseline McKay needs to beat for (4,5).

   Validation gates (iso class counts must match):
     (2,4) -> 11   (2,5) -> 26   (3,4) -> 66

   Default cells skip (2,5) and (3,5) because McKay is 5-15x slower per
   emission than the cheap pipeline and sequential parallel-off mode
   compounds that. Override via env var to widen the run.

   Run:
     wolframscript -file src/test_streaming_mckay.wl
   Restrict / extend cells via env var:
     COMB_TEST_CELLS="2,4;3,4" wolframscript -file src/test_streaming_mckay.wl
     COMB_TEST_CELLS="2,5"     wolframscript -file src/test_streaming_mckay.wl
*)

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator.wl"}]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator_bliss.wl"}]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator_mckay.wl"}]];

defaultCells = {{2, 4}, {3, 4}};
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

Print["Profiling cells (sequential mode): ", cells];
Print["Expected |iso|: ",
  Lookup[expectedCounts, Key[#], "?"] & /@ cells];
Print[""];

(* MaxMemoryUsed[] is monotone non-decreasing across the session: it
   tracks the lifetime high-water mark. To attribute peak memory to a
   specific run, snapshot before/after and take the delta. *)
profile[label_String, fn_, p_Integer, q_Integer] := Module[
  {prevMax, t, r, peakDelta, lifetimePeak, n},
  ClearSystemCache[];
  prevMax = MaxMemoryUsed[];
  {t, r} = AbsoluteTiming[fn[p, q, Parallel -> False]];
  lifetimePeak = MaxMemoryUsed[];
  peakDelta = N[(lifetimePeak - prevMax) / 2.0^20];
  n = Length[r["isoReps"]];
  Print["  ", StringPadRight[label, 8],
    "  |iso|=", StringPadRight[ToString[n], 6],
    "  totalEmitted=", StringPadRight[ToString[r["totalEmitted"]], 8],
    "  time=", StringPadRight[ToString[Round[t, 0.01]] <> "s", 12],
    "  peakDelta=", Round[peakDelta, 0.1], " MB"];
  <|"label" -> label, "n" -> n, "time" -> t, "peakDelta" -> peakDelta|>];

Do[
  Module[{p = cell[[1]], q = cell[[2]], expected, results, ok, mismatches},
    expected = Lookup[expectedCounts, Key[cell], "?"];
    Print["----- cell (", p, ",", q, ")   expected |iso|=", expected, " -----"];
    results = {
      profile["cheap", streamingEnumeratePure,      p, q],
      profile["bliss", streamingEnumeratePureBLISS, p, q],
      profile["mckay", streamingEnumeratePureMcKay, p, q]
    };
    ok = If[expected === "?",
      Length[DeleteDuplicates[#["n"] & /@ results]] === 1,
      AllTrue[results, #["n"] === expected &]];
    If[!ok,
      mismatches = #["label"] -> #["n"] & /@ results;
      Print["  *** MISMATCH at (", p, ",", q, "): ", mismatches, " ***"];
      Abort[]];
    Print["    -> all three pipelines agree on |iso|=",
      First[results]["n"], "   ", "(gate ok)"];
    Print[""]],
  {cell, cells}];

Print["all correctness gates pass."];
