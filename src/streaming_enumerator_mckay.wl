(* streaming_enumerator_mckay.wl
   McKay-style canonical-augmentation enumeration. Prunes DFS
   branches at every internal step with a canonical-augmentation predicate,
   then uses BLISS keys to dedup any cross-start duplicates at the leaves.

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
   Aut(G(S)). This selects canonical augmentations within a DFS subtree.

   Note: at the DFS root (single starting vertex), the predicate is
   trivially True (one V-vertex, one orbit). Different starting states
   correspond to different bipartite graphs and remain distinct DFS
   subtrees. BLISS canonical-key dedup at the leaves catches cross-subtree
   duplicates. In practice the predicate still prunes aggressively.

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
   vertex to remove" in McKay's framework.

   Integer-labeled now (2026-05-13 Phase 4b): V vertices are 1..n in
   bipartiteIncidenceGraph, returns the integer V-label k in {1..n}
   that gets the largest canonical position. The McKay DFS predicate
   then checks `=== Length[state]` exactly as before. *)
canonicalRemovalVSide[cmplx_List] := Module[
  {g, vList, n, canonG, isoMap, canonPositions, maxPos},
  g = bipartiteIncidenceGraph[cmplx];
  vList = Sort @ DeleteDuplicates @ Flatten[cmplx];
  n = Length[vList];
  canonG = CanonicalGraph[g];
  isoMap = First[FindGraphIsomorphism[g, canonG]];
  (* V-labels in the bipartite graph are 1..n (post-relabel inside
     bipartiteIncidenceGraph); look up their canonical positions and
     pick the V-label with the largest. Map the relabeled index back
     to the original vertex via vList. For DFS use this is identity
     (vList === Range[n]), so the returned integer equals the depth
     of the just-added vertex and the McKay predicate's
     `=== Length[state]` check matches. *)
  canonPositions = Lookup[isoMap, Range[n]];
  maxPos = First[Ordering[canonPositions, -1]];
  vList[[maxPos]]
];

(* Is `candidate` (an integer V-label in 1..n) in the orbit of
   canonicalRemovalVSide[cmplx] under the automorphism group of
   bipartiteIncidenceGraph[cmplx]?

   IMPORTANT: GraphAutomorphismGroup returns a permutation group on
   integer positions in VertexList[g]. With integer-labeled graphs the
   vertex labels are themselves positions in VertexList (since we
   construct g via Graph[Range[n+3q], ...]), so candidate IS its own
   position.

   Cheap short-circuit when candidate IS the canonical-removal vertex
   (covers most calls during DFS). The current McKay predicate uses
   strict equality and never invokes this orbit check; kept for future
   reformulations (plan step 4b.5). *)
isInCanonicalRemovalOrbit[cmplx_List, candidate_Integer] := Module[
  {g, canonRem, autGroup, posOrbits, hostOrbit, vLabels, n},
  canonRem = canonicalRemovalVSide[cmplx];
  If[canonRem === candidate, Return[True]];
  g = bipartiteIncidenceGraph[cmplx];
  n = Length @ DeleteDuplicates @ Flatten[cmplx];
  vLabels = Range[n];
  autGroup = GraphAutomorphismGroup[g];
  posOrbits = GroupOrbits[autGroup, vLabels];
  hostOrbit = First @ Select[posOrbits, MemberQ[#, canonRem] &];
  MemberQ[hostOrbit, candidate]
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
      canonicalRemovalVSide[convertToFacets[state]] === Length[state]
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
