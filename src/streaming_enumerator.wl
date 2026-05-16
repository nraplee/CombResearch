(* streaming_enumerator.wl
   Streaming variant of pure-simplicial-complex enumeration with online
   iso-class bucketing. Parallelized over starting states so each
   subkernel runs an independent DFS+local-bucket pass; results are
   merged at the end.

   Two functions are exposed:

     - chooseNonIsoBucketed[allLab]
         Drop-in replacement for ECGrav`ChooseNonIsomorphicSimplicialComplexes
         on a single list. Hashes each input by a relabeling-invariant
         tuple, groups by hash, then runs pairwise iso testing only within
         buckets. Reduces an O(n^2) pairwise scan to O(n) hashes plus
         O(b^2) within-bucket work for the largest bucket b.

     - streamingEnumeratePure[p, q, Parallel -> True | False]
         Reimplements ECGrav`GenerateAllFacetLabeledPureSimplicialComplexes
         (PureComplexes.wl line 2619) as a DFS that emits one finished
         facet-labeled complex at a time. Each emitted complex flows
         immediately into a local bucket map keyed by canonicalKey;
         within each bucket, IsomorphicSimplicialComplexQ confirms
         uniqueness. Parallel mode distributes starting states across
         subkernels; each kernel maintains a local bucket map and we
         merge at the end. Returns:
           <|"isoReps"     -> {complex_1, complex_2, ...},
             "totalEmitted" -> n,
             "numBuckets"   -> k|>
         Memory bounded by k (number of distinct canonical keys), not by
         the total facet-labeled count.

   The algorithm matches ECGrav's:
     * Each "complex-in-progress" is a list of vertex membership-subsets
       (each subset ⊆ {1..q} naming which facets the vertex belongs to).
     * AddOneVertex marks a subset i unavailable when adding a vertex with
       membership ⊇ i would either fill a facet past purity p (Length[i]==1
       case) or make all facets in i share p common vertices (Length[i]>1
       case, which would force two facets to coincide).
     * Lex constraint Order[#, last] >= 0 ensures each labeled complex is
       generated in exactly one canonical vertex order.
     * Starting states are facetSubsets[[q;;-1]] — skip the first q-1
       singletons; they're equivalent under the lex symmetry to the
       starts we keep.

   This is the baseline "cheap-key" enumerator. It is reliable for small
   cells, but p=4 q>=5 should use streamingEnumeratePureMcKay to avoid OOM.
*)

Needs["ECGrav`"];

(* ============================================================
   Canonical-key bucketing
   ============================================================ *)

(* Cheap, strong-enough iso invariant. Tuple of:
     - numV (number of vertices)
     - sorted vertex-degree multiset (degree = number of facets containing v)
     - sorted facet-pair-overlap multiset (|f_i ∩ f_j| for all i<j)
   All three components are invariant under vertex AND facet relabeling. *)
canonicalKey[complex_List] := Module[
  {q, verts, vDegrees, pairOverlaps},
  q = Length[complex];
  verts = DeleteDuplicates @ Flatten[complex];
  vDegrees = Sort @ (
    Function[v, Count[complex, _List?(MemberQ[#, v] &)]] /@ verts);
  pairOverlaps = Sort @ (
    Length[Intersection[complex[[#1]], complex[[#2]]]] & @@@
      Subsets[Range[q], {2}]);
  {Length[verts], vDegrees, pairOverlaps}
];

(* Within-bucket dedupe — same algorithm as ChooseNonIsomorphic's
   single-list overload (PureComplexes.wl line 1574), but restricted to
   one bucket so the outer scan is small. *)
chooseNonIsoBucketWithin[bucket_List] := Module[
  {result = {}, remaining = bucket, head},
  While[Length[remaining] > 0,
    head = First[remaining];
    AppendTo[result, head];
    remaining = Select[Rest[remaining],
      ! IsomorphicSimplicialComplexQ[head, #] &]];
  result
];

chooseNonIsoBucketed[allLab_List] := Module[
  {keys, byKey, reps},
  keys = ParallelMap[canonicalKey, allLab,
    DistributedContexts -> Automatic];
  byKey = GroupBy[Transpose[{keys, allLab}], First -> Last];
  reps = If[Length[#] <= 1, #, chooseNonIsoBucketWithin[#]] & /@
    Values[byKey];
  Flatten[reps, 1]
];

(* ============================================================
   Streaming enumerator — single-start worker
   ============================================================ *)

(* Run DFS from one starting vertex membership-set v0, maintaining a
   local bucket map. Returns <|"map" -> localMap, "count" -> localCount|>.
   Pure function in (v0, p, q, target, facetSubsets) so it can be
   distributed to subkernels. *)
streamingFromStart[v0_List, p_Integer, q_Integer, target_Integer,
                   facetSubsets_List] := Module[
  {localMap, localCount, addOneVertex, convertToFacets, emit, dfs},

  Block[{$RecursionLimit = Infinity, $IterationLimit = Infinity},
    localMap = <||>;
    localCount = 0;

    addOneVertex[state_List] := Module[
      {vertexDegree, unavail, avail, lastV},
      vertexDegree = Association @ Table[
        i -> Count[state, _List?(SubsetQ[#, i] &)],
        {i, facetSubsets}];
      unavail = Cases[facetSubsets,
        i_ /; (Length[i] == 1 && vertexDegree[i] == p)
           || (Length[i] > 1 && vertexDegree[i] == p - 1)];
      avail = Fold[
        Function[{x, y}, Select[x, ! SubsetQ[#, y] &]],
        facetSubsets, unavail];
      lastV = Last[state];
      Select[avail, Order[#, lastV] >= 0 &]
    ];

    convertToFacets[state_List] := With[{n = Length[state]},
      Reverse @ Table[
        Select[Range[n], MemberQ[state[[#]], f] &],
        {f, q}]
    ];

    emit[finishedState_] := Module[
      {cmplx, key, bucket, isoFound},
      cmplx = convertToFacets[finishedState];
      key = canonicalKey[cmplx];
      (* Key[...] wrapper required: canonicalKey returns a List, and
         Lookup[assoc, list, default] otherwise treats list as a
         vector of keys for multi-key lookup. *)
      bucket = Lookup[localMap, Key[key], {}];
      isoFound = AnyTrue[bucket,
        IsomorphicSimplicialComplexQ[cmplx, #] &];
      If[!isoFound, localMap[key] = Append[bucket, cmplx]];
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
   Streaming enumerator — top-level driver
   ============================================================ *)

(* Merge two bucket-rep lists for the same canonical key into a single
   deduped rep list. Used as the combiner in Merge[]. *)
mergeBucketReps[lists_List] := chooseNonIsoBucketWithin[Flatten[lists, 1]];

Options[streamingEnumeratePure] = {Parallel -> True};

streamingEnumeratePure[purity_Integer, facetOrder_Integer,
                       OptionsPattern[]] := Module[
  {p = purity, q = facetOrder, target, facetSubsets, starts,
   useParallel = OptionValue[Parallel],
   localResults, mergedMap, totalEmitted},

  target = p * q;
  facetSubsets = Subsets[Range[q]][[2;;-1]];
  starts = facetSubsets[[q;;-1]];

  If[useParallel,
    (* Subkernels need ECGrav (for IsomorphicSimplicialComplexQ) and our
       canonicalKey + streamingFromStart definitions. *)
    ParallelEvaluate[Needs["ECGrav`"]; ClearSystemCache[]];
    DistributeDefinitions[
      canonicalKey, streamingFromStart, chooseNonIsoBucketWithin];

    localResults = ParallelMap[
      streamingFromStart[#, p, q, target, facetSubsets] &,
      starts,
      Method -> "FinestGrained",
      DistributedContexts -> Automatic
    ],

    localResults = streamingFromStart[#, p, q, target, facetSubsets] & /@ starts
  ];

  totalEmitted = Total[#["count"] & /@ localResults];
  mergedMap = Merge[#["map"] & /@ localResults, mergeBucketReps];

  <|"isoReps"     -> Flatten[Values[mergedMap], 1],
    "totalEmitted" -> totalEmitted,
    "numBuckets"   -> Length[mergedMap]|>
];
