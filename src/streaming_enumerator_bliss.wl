(* streaming_enumerator_bliss.wl
   Option B of docs/PLAN_TRUTH_ENUMERATION.md § "Alternative enumeration
   approaches": replace the cheap 3-tuple canonicalKey of
   streaming_enumerator.wl with a true canonical form via Mathematica's
   CanonicalGraph (BLISS algorithm) on the bipartite face-incidence graph.

   STATUS (2026-05-07): correct but NOT a standalone speedup.
   Empirically validated against expected iso-class counts on the five
   reachable cells (2,4) (2,5) (2,6) (3,4) (3,5). Speedup vs the cheap-key
   pipeline ranges from 1.04× to 2.31× — within noise. Root cause:
   benchmarks at (2,6) show the DFS recursion itself accounts for ≈ 95 %
   of wall-clock; iso testing in the cheap pipeline is a small constant.
   Replacing one constant cost with another doesn't shift the ceiling.

   This module is kept in the codebase as the canonical-form primitive
   that Option D (McKay canonical-augmentation enumeration) needs. The
   real speedup comes from D, which generates each iso class exactly
   once and so eliminates the DFS redundancy (e.g. 12055 → 68 emissions
   at (2,6)). D's augmentation predicate calls bipartiteIncidenceGraph
   and blissCanonicalKey on partial states — both work as-is for any
   list of facets, not only full q-facet states.

   API mirrors streaming_enumerator.wl one-for-one:
     - blissCanonicalKey[complex]       — true canonical form (sorted edge list)
     - streamingEnumeratePureBLISS[p,q] — same {isoReps, totalEmitted, numBuckets}

   ============================================================
   Bipartite encoding
   ============================================================
   For a pure simplicial complex c (list of q facets, each a sorted
   p-subset of vertex labels), build a labeled bipartite graph G(c):

     - V-side: one vertex per element of ⋃ c, labeled "v_<n>"
     - F-side: one vertex per facet, labeled "f_<i>"
     - Bipartite edges: (v_n, f_i) iff vertex n is in facet i
     - Triangle gadget per facet: two new tag vertices "t_<i>_1",
       "t_<i>_2" with edges (f_i, t_i_1), (f_i, t_i_2), (t_i_1, t_i_2)

   The triangle gadget is the key trick: bipartite graphs are triangle-
   free, so every triangle in G(c) contains exactly one F-side vertex.
   That makes F-side vertices structurally distinguishable from V-side
   under any graph automorphism — no automorphism can permute V↔F.
   Therefore CanonicalGraph[G(c)] preserves the simplicial-complex
   structure and equal canonical graphs ⇔ isomorphic complexes.

   Two complexes c1, c2 are isomorphic ⇔
     CanonicalGraph[G(c1)] === CanonicalGraph[G(c2)]
*)

Needs["ECGrav`"];

(* ============================================================
   Bipartite face-incidence graph with side-distinguishing gadget
   ============================================================ *)

bipartiteIncidenceGraph[complex_List] := Module[
  {q, vNode, fNode, tNode, bipEdges, gadgetEdges},
  q = Length[complex];
  vNode[v_] := "v_" <> ToString[v];
  fNode[i_] := "f_" <> ToString[i];
  tNode[i_, k_] := "t_" <> ToString[i] <> "_" <> ToString[k];
  bipEdges = Flatten @ Table[
    UndirectedEdge[vNode[v], fNode[i]],
    {i, q}, {v, complex[[i]]}];
  gadgetEdges = Flatten @ Table[
    {UndirectedEdge[fNode[i], tNode[i, 1]],
     UndirectedEdge[fNode[i], tNode[i, 2]],
     UndirectedEdge[tNode[i, 1], tNode[i, 2]]},
    {i, q}];
  Graph[Join[bipEdges, gadgetEdges]]
];

(* Canonical form via BLISS. Two complexes have equal canonical keys
   iff they are isomorphic.

   We extract the canonical EdgeList rather than returning the Graph
   itself: Mathematica Associations key on Hash, and hashing a Graph
   walks its full internal representation, which dominated wall-clock
   in early benchmarks. Sorted EdgeList is a cheap-to-hash list of
   integer pairs and equally unique (CanonicalGraph guarantees the
   canonical labeling is deterministic, so the canonical edge set is
   too). *)
blissCanonicalKey[complex_List] :=
  Sort @ (List @@@ EdgeList @ CanonicalGraph @
    bipartiteIncidenceGraph[complex]);

(* ============================================================
   Streaming enumerator — single-start DFS worker
   ============================================================
   Same DFS as streaming_enumerator.wl::streamingFromStart, but the
   emit step records only ONE representative per canonical key
   (no within-bucket dedup needed: keys are unique by construction). *)

streamingFromStartBLISS[v0_List, p_Integer, q_Integer,
                       target_Integer, facetSubsets_List] := Module[
  {localMap, localCount, addOneVertex, convertToFacets, emit, dfs},
  Block[{$RecursionLimit = Infinity, $IterationLimit = Infinity},
    localMap = <||>;
    localCount = 0;

    (* Which membership-subsets can extend `state` without violating
       purity p or forcing two facets to coincide? See
       streaming_enumerator.wl for the full derivation — this code is
       byte-for-byte the same logic. *)
    addOneVertex[state_List] := Module[
      {vertexDegree, unavail, avail, lastV},
      vertexDegree = Association @ Table[
        i -> Count[state, _List?(SubsetQ[#, i] &)],
        {i, facetSubsets}];
      unavail = Cases[facetSubsets,
        i_ /; (Length[i] == 1 && vertexDegree[i] == p)
           || (Length[i] > 1 && vertexDegree[i] == p - 1)];
      avail = Fold[
        Function[{x, y}, Select[x, !SubsetQ[#, y] &]],
        facetSubsets, unavail];
      lastV = Last[state];
      Select[avail, Order[#, lastV] >= 0 &]
    ];

    convertToFacets[state_List] := With[{n = Length[state]},
      Reverse @ Table[
        Select[Range[n], MemberQ[state[[#]], f] &],
        {f, q}]
    ];

    (* First-seen rep wins per canonical key. *)
    emit[finishedState_] := Module[{cmplx, key},
      cmplx = convertToFacets[finishedState];
      key = blissCanonicalKey[cmplx];
      If[!KeyExistsQ[localMap, key], localMap[key] = cmplx];
      localCount++;
    ];

    dfs[state_List, currTotal_Integer] := If[
      currTotal == target,
      emit[state],
      Do[dfs[Append[state, v], currTotal + Length[v]],
        {v, addOneVertex[state]}]
    ];

    dfs[{v0}, Length[v0]];

    <|"map" -> localMap, "count" -> localCount|>
  ]
];

(* ============================================================
   Top-level driver
   ============================================================ *)

Options[streamingEnumeratePureBLISS] = {Parallel -> True};

streamingEnumeratePureBLISS[purity_Integer, facetOrder_Integer,
                            OptionsPattern[]] := Module[
  {p = purity, q = facetOrder, target, facetSubsets, starts,
   useParallel = OptionValue[Parallel],
   localResults, mergedMap, totalEmitted},

  target = p * q;
  facetSubsets = Subsets[Range[q]][[2;;-1]];
  starts = facetSubsets[[q;;-1]];

  If[useParallel,
    (* Subkernels need our definitions. CanonicalGraph is built-in;
       ECGrav not needed at workers (no IsomorphicSimplicialComplexQ
       calls inside the loop). *)
    DistributeDefinitions[
      bipartiteIncidenceGraph, blissCanonicalKey,
      streamingFromStartBLISS];

    localResults = ParallelMap[
      streamingFromStartBLISS[#, p, q, target, facetSubsets] &,
      starts,
      Method -> "FinestGrained",
      DistributedContexts -> Automatic],

    localResults = streamingFromStartBLISS[#, p, q, target, facetSubsets] & /@ starts
  ];

  totalEmitted = Total[#["count"] & /@ localResults];
  (* Cross-kernel merge: a key may appear in multiple kernels (same iso
     class reached via different starting states). Pick any rep. *)
  mergedMap = Merge[#["map"] & /@ localResults, First];

  <|"isoReps"      -> Values[mergedMap],
    "totalEmitted" -> totalEmitted,
    "numBuckets"   -> Length[mergedMap]|>
];
