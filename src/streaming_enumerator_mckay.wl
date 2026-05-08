(* streaming_enumerator_mckay.wl
   Option D of docs/PLAN_TRUTH_ENUMERATION.md § "Alternative enumeration
   approaches": McKay-style canonical-augmentation enumeration. Generates
   each iso class via exactly one DFS path by pruning at every internal
   step on a canonical-augmentation predicate.

   WHY: benchmarks at (2,6) show the existing DFS visits 12,055 leaves
   for only 68 iso classes — a 177× redundancy. The DFS recursion itself
   is ~95% of wall-clock (see streaming_enumerator_bliss.wl header for
   the data). Option B (BLISS canonical form) didn't help because it
   only optimizes the leaf-dedup step; this version cuts the DFS work
   directly.

   IDEA (McKay 1998, "Isomorph-free exhaustive generation"): given a
   partial state S of size n, define the "canonical removal" vertex
   m(S) — the V-side vertex with the largest canonical label in the
   bipartite face-incidence graph G(S) under BLISS canonicalization.
   The canonical-augmentation predicate accepts S iff the just-added
   vertex (the one at position n) is in the orbit of m(S) under
   Aut(G(S)). This guarantees: among all DFS paths that could reach
   any iso class, exactly one passes the predicate at every step.

   Note: at the DFS root (single starting vertex), the predicate is
   trivially True (one V-vertex, one orbit). Different starting states
   correspond to different bipartite graphs and remain distinct DFS
   subtrees. We rely on BLISS canonical-key dedup at the leaves to
   catch any cross-subtree duplicates (different starts that reach the
   same iso class). In practice the predicate prunes aggressively
   within each subtree even before the cross-subtree dedup fires.

   API mirrors streaming_enumerator.wl one-for-one:
     - streamingEnumeratePureMcKay[p, q] — same {isoReps, totalEmitted, numBuckets}

   Reuses bipartiteIncidenceGraph and blissCanonicalKey from
   streaming_enumerator_bliss.wl.
*)

Needs["ECGrav`"];

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator_bliss.wl"}]];

(* ============================================================
   Canonical-augmentation predicate
   ============================================================ *)

(* The V-side vertex of bipartiteIncidenceGraph[cmplx] that receives
   the largest canonical label. Equivalently: the canonical "last
   vertex to remove" in McKay's framework. *)
canonicalRemovalVSide[cmplx_List] := Module[
  {g, n, vLabels, canonG, isoMap, canonLabels, maxPos},
  g = bipartiteIncidenceGraph[cmplx];
  n = Length[DeleteDuplicates[Flatten[cmplx]]];
  vLabels = "v_" <> ToString[#] & /@ Range[n];
  canonG = CanonicalGraph[g];
  isoMap = First[FindGraphIsomorphism[g, canonG]];
  canonLabels = Lookup[isoMap, vLabels];
  maxPos = First[Ordering[canonLabels, -1]];
  vLabels[[maxPos]]
];

(* Is `candidate` in the orbit of canonicalRemovalVSide[cmplx] under
   the automorphism group of bipartiteIncidenceGraph[cmplx]?

   IMPORTANT: GraphAutomorphismGroup returns a permutation group on
   integer positions in VertexList[g], not on String labels directly.
   We therefore translate vertex labels to positions, compute orbits
   on positions, then check membership.

   Cheap short-circuit when candidate IS the canonical-removal vertex
   (covers most calls during DFS). *)
isInCanonicalRemovalOrbit[cmplx_List, candidate_String] := Module[
  {g, vertList, canonRem, canonRemPos, candidatePos, vPositions,
   autGroup, posOrbits, hostPosOrbit},
  canonRem = canonicalRemovalVSide[cmplx];
  If[canonRem === candidate, Return[True]];
  g = bipartiteIncidenceGraph[cmplx];
  vertList = VertexList[g];
  canonRemPos = First @ FirstPosition[vertList, canonRem];
  candidatePos = First @ FirstPosition[vertList, candidate];
  vPositions = First @ FirstPosition[vertList, #] & /@
    ("v_" <> ToString[#] & /@
      Range[Length[DeleteDuplicates[Flatten[cmplx]]]]);
  autGroup = GraphAutomorphismGroup[g];
  posOrbits = GroupOrbits[autGroup, vPositions];
  hostPosOrbit = First @ Select[posOrbits, MemberQ[#, canonRemPos] &];
  MemberQ[hostPosOrbit, candidatePos]
];

(* ============================================================
   Per-start DFS worker with McKay pruning
   ============================================================ *)

streamingFromStartMcKay[v0_List, p_Integer, q_Integer,
                       target_Integer, facetSubsets_List] := Module[
  {localMap, localCount, addOneVertex, convertToFacets, isMcKayValid,
   emit, dfs},
  Block[{$RecursionLimit = Infinity, $IterationLimit = Infinity},
    localMap = <||>;
    localCount = 0;

    (* No lex constraint here; lex's canonical choice conflicts with
       McKay's canonical-removal vertex. McKay alone enforces canonical
       augmentation. *)
    addOneVertex[state_List] := Module[
      {vertexDegree, unavail, avail},
      vertexDegree = Association @ Table[
        i -> Count[state, _List?(SubsetQ[#, i] &)],
        {i, facetSubsets}];
      unavail = Cases[facetSubsets,
        i_ /; (Length[i] == 1 && vertexDegree[i] == p)
           || (Length[i] > 1 && vertexDegree[i] == p - 1)];
      Fold[
        Function[{x, y}, Select[x, !SubsetQ[#, y] &]],
        facetSubsets, unavail]
    ];

    convertToFacets[state_List] := With[{n = Length[state]},
      Reverse @ Table[
        Select[Range[n], MemberQ[state[[#]], f] &],
        {f, q}]
    ];

    (* The McKay predicate. State of size 1 trivially passes.
       Strict equality (no orbit fallback) — the just-added vertex
       must BE the canonical-removal vertex. This gives exactly one
       canonical-augmentation path per iso class (per starting state).
       Cross-start duplicates are caught by the leaf BLISS dedup. *)
    isMcKayValid[state_List] := If[
      Length[state] <= 1,
      True,
      canonicalRemovalVSide[convertToFacets[state]] ===
        ("v_" <> ToString[Length[state]])
    ];

    emit[finishedState_] := Module[{cmplx, key},
      cmplx = convertToFacets[finishedState];
      key = blissCanonicalKey[cmplx];
      If[!KeyExistsQ[localMap, key], localMap[key] = cmplx];
      localCount++;
    ];

    dfs[state_List, currTotal_Integer] := If[
      currTotal == target,
      emit[state],
      Do[
        With[{newState = Append[state, v]},
          If[isMcKayValid[newState],
            dfs[newState, currTotal + Length[v]]]],
        {v, addOneVertex[state]}]
    ];

    dfs[{v0}, Length[v0]];

    <|"map" -> localMap, "count" -> localCount|>
  ]
];

(* ============================================================
   Top-level driver
   ============================================================ *)

Options[streamingEnumeratePureMcKay] = {Parallel -> True};

streamingEnumeratePureMcKay[purity_Integer, facetOrder_Integer,
                            OptionsPattern[]] := Module[
  {p = purity, q = facetOrder, target, facetSubsets, starts,
   useParallel = OptionValue[Parallel],
   localResults, mergedMap, totalEmitted},

  target = p * q;
  facetSubsets = Subsets[Range[q]][[2;;-1]];
  starts = facetSubsets[[q;;-1]];

  If[useParallel,
    DistributeDefinitions[
      bipartiteIncidenceGraph, blissCanonicalKey,
      canonicalRemovalVSide, isInCanonicalRemovalOrbit,
      streamingFromStartMcKay];

    localResults = ParallelMap[
      streamingFromStartMcKay[#, p, q, target, facetSubsets] &,
      starts,
      Method -> "FinestGrained",
      DistributedContexts -> Automatic],

    localResults = streamingFromStartMcKay[#, p, q, target, facetSubsets] & /@ starts
  ];

  totalEmitted = Total[#["count"] & /@ localResults];
  mergedMap = Merge[#["map"] & /@ localResults, First];

  <|"isoReps"      -> Values[mergedMap],
    "totalEmitted" -> totalEmitted,
    "numBuckets"   -> Length[mergedMap]|>
];
