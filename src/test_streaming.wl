(* test_streaming.wl
   Validate src/streaming_enumerator.wl against ECGrav's eager generator
   on small (p, q) where we know the canonical answers.

   Canonical answers (from CLAUDE.md, render_uniformity_check.wl,
   render_sampler_progress.wl, and Phase 1 scaling probe):
     (2, 4) -> 70 facet-labeled, 11 iso classes
     (2, 5) -> 794 facet-labeled, 26 iso classes
     (3, 4) -> 666 facet-labeled, 66 iso classes
     (2, 6) -> 12055 facet-labeled, 68 iso classes  (slow — 4 min)
     (3, 5) -> 28344 facet-labeled, 445 iso classes (slow — 26 min eager)

   Tests:
     A. chooseNonIsoBucketed on the eager output matches |iso| of
        ChooseNonIsomorphicSimplicialComplexes for each cell.
     B. streamingEnumeratePure[p, q] returns isoReps with the same
        |iso| count, AND totalEmitted == |allLab|.

   Cells covered by default: (2,4), (2,5), (3,4). The bigger cells
   (2,6), (3,5) are guarded behind COMB_TEST_SLOW=1 to keep this
   script as a quick correctness check by default.
*)

Needs["ECGrav`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "streaming_enumerator.wl"}]];

cells = {{2, 4, 70, 11}, {2, 5, 794, 26}, {3, 4, 666, 66}};

If[StringQ[Environment["COMB_TEST_SLOW"]] &&
   Environment["COMB_TEST_SLOW"] === "1",
  AppendTo[cells, {2, 6, 12055, 68}];
  AppendTo[cells, {3, 5, 28344, 445}]];

allPass = True;
fail[msg_] := (allPass = False; Print["  FAIL: ", msg]);
pass[msg_] := Print["  ok:   ", msg];

testCell[{p_, q_, expectedAllLab_, expectedIso_}] := Module[
  {tEager, allLab, tNaive, isoNaive,
   tBucketed, isoBucketed, tStream, sr},

  Print["----- (", p, ", ", q, ") -----"];

  (* Eager generation (ECGrav) *)
  {tEager, allLab} = AbsoluteTiming[
    GenerateAllFacetLabeledPureSimplicialComplexes[{p, q}]];
  Print["  eager gen:           ", Length[allLab], " complexes, ",
    Round[tEager, 0.01], "s"];
  If[Length[allLab] === expectedAllLab,
    pass["allLab matches expected " <> ToString[expectedAllLab]],
    fail["allLab " <> ToString[Length[allLab]] <>
      " != expected " <> ToString[expectedAllLab]]];

  (* Test A: chooseNonIsoBucketed vs ChooseNonIsomorphic *)
  {tNaive, isoNaive} = AbsoluteTiming[
    ChooseNonIsomorphicSimplicialComplexes[allLab]];
  {tBucketed, isoBucketed} = AbsoluteTiming[chooseNonIsoBucketed[allLab]];
  Print["  iso (naive):         ", Length[isoNaive], " classes, ",
    Round[tNaive, 0.01], "s"];
  Print["  iso (bucketed):      ", Length[isoBucketed], " classes, ",
    Round[tBucketed, 0.01], "s",
    "    speedup ", Round[tNaive / tBucketed, 0.1], "x"];
  If[Length[isoBucketed] === Length[isoNaive],
    pass["bucketed |iso| matches naive |iso|"],
    fail["bucketed |iso| " <> ToString[Length[isoBucketed]] <>
      " != naive |iso| " <> ToString[Length[isoNaive]]]];
  If[Length[isoBucketed] === expectedIso,
    pass["bucketed |iso| matches canonical " <> ToString[expectedIso]],
    fail["bucketed |iso| " <> ToString[Length[isoBucketed]] <>
      " != canonical " <> ToString[expectedIso]]];

  (* Test B: streamingEnumeratePure *)
  {tStream, sr} = AbsoluteTiming[streamingEnumeratePure[p, q]];
  Print["  streaming:           |isoReps|=", Length[sr["isoReps"]],
    "  totalEmitted=", sr["totalEmitted"],
    "  numBuckets=", sr["numBuckets"], ", ",
    Round[tStream, 0.01], "s"];
  If[sr["totalEmitted"] === Length[allLab],
    pass["streaming totalEmitted matches eager |allLab|"],
    fail["streaming totalEmitted " <> ToString[sr["totalEmitted"]] <>
      " != eager |allLab| " <> ToString[Length[allLab]]]];
  If[Length[sr["isoReps"]] === expectedIso,
    pass["streaming |isoReps| matches canonical " <> ToString[expectedIso]],
    fail["streaming |isoReps| " <> ToString[Length[sr["isoReps"]]] <>
      " != canonical " <> ToString[expectedIso]]];
];

Do[testCell[cell], {cell, cells}];

Print[""];
Print[If[allPass, "ALL PASS", "FAILURES — see above"]];
If[!allPass, Exit[1]];
