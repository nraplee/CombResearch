(* probe_mckay_primitives.wl
   Time-attribution probe for canonicalRemovalVSide. Splits the per-state
   cost across its three subroutines:
     1. bipartiteIncidenceGraph[cmplx]       (graph construction)
     2. CanonicalGraph[g]                    (BLISS)
     3. FindGraphIsomorphism[g, canonG]      (recover canonical labeling)

   For each of a handful of representative complexes from the (2,4)..(3,4)
   reachable cells, time each step over N repetitions and report mean
   microseconds. Identifies which step to optimize first.
*)

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator_bliss.wl"}]];

(* Sample complexes: small to medium. Drawn from things the DFS would
   encounter at (2,4) and (3,4). Partial states are valid pure
   complexes of any size in {1..pq}. *)
testComplexes = {
  (* (p=2, q=4) small partial: 3 facets of size 2 sharing a vertex *)
  {{1, 2}, {1, 3}, {1, 4}},
  (* (p=2, q=4) full: 4 facets *)
  {{1, 2}, {2, 3}, {3, 4}, {4, 5}},
  (* (p=3, q=4) small partial *)
  {{1, 2, 3}, {1, 2, 4}},
  (* (p=3, q=4) full: 4 triangles *)
  {{1, 2, 3}, {1, 2, 4}, {1, 3, 5}, {2, 4, 5}},
  (* (p=3, q=4) max-vertex full *)
  {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}, {10, 11, 12}}
};

timePer[label_String, expr_Hold, n_Integer] := Module[{t, us},
  t = First @ AbsoluteTiming[Do[ReleaseHold[expr], {n}]];
  us = N[1.0*^6 * t / n];
  Print["    ", StringPadRight[label, 30], NumberForm[us, {8, 1}], " us"];
  us];

reps = 100;

Do[
  Module[{cmplx = c, g, canonG, sumUs, tBuild, tCanon, tFind, tFull},
    Print["----- cmplx: ", c, " -----"];
    g = bipartiteIncidenceGraph[cmplx];
    canonG = CanonicalGraph[g];

    tBuild = timePer["bipartiteIncidenceGraph",
      Hold[bipartiteIncidenceGraph[cmplx]], reps];
    tCanon = timePer["CanonicalGraph",
      Hold[CanonicalGraph[g]], reps];
    tFind  = timePer["FindGraphIsomorphism",
      Hold[First[FindGraphIsomorphism[g, canonG]]], reps];

    (* Full canonicalRemovalVSide-equivalent path. *)
    tFull = timePer["full predicate (sum-ish)",
      Hold[
        Module[{g2, canonG2, isoMap, n2, vLabels, canonLabels},
          g2 = bipartiteIncidenceGraph[cmplx];
          canonG2 = CanonicalGraph[g2];
          isoMap = First[FindGraphIsomorphism[g2, canonG2]];
          n2 = Length[DeleteDuplicates[Flatten[cmplx]]];
          vLabels = "v_" <> ToString[#] & /@ Range[n2];
          canonLabels = Lookup[isoMap, vLabels];
          vLabels[[First[Ordering[canonLabels, -1]]]]]],
      reps];

    sumUs = tBuild + tCanon + tFind;
    Print["    sum (build+canon+find)        ", NumberForm[sumUs, {8, 1}], " us"];
    Print["    full predicate                ", NumberForm[tFull,  {8, 1}], " us"];
    Print[""];
  ],
  {c, testComplexes}];

Print["done."];
