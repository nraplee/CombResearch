(* ::Package:: *)

(* Enumeration.wl: exact enumeration of the isomorphism classes of pure
   simplicial complexes. Loaded by Kernel/CombResearch.wl into
   CombResearch`Private`; the public symbols are declared there.

   Three enumerators, all the same DFS over "complexes in progress" (moved
   verbatim in Phase 4 from src/streaming_enumerator.wl, _bliss.wl and
   _mckay.wl, deleted in Phase 5):

     cheap  (streamingEnumeratePure)       cheap invariant key, then
                                           IsomorphicSimplicialComplexQ inside
                                           each bucket. Reliable for small
                                           cells; runs out of memory at (4,5).
     bliss  (streamingEnumeratePureBLISS)  BLISS canonical key at the leaves.
                                           Correct, not faster than cheap.
     mckay  (streamingEnumeratePureMcKay)  McKay canonical augmentation:
                                           prunes the DFS at every step, BLISS
                                           key dedup across starts. The
                                           production path at p = 4.

   The DFS matches ECGrav's GenerateAllFacetLabeledPureSimplicialComplexes:
     * Each complex in progress is a list of vertex membership subsets (each
       subset of {1..q} names the facets the vertex belongs to).
     * addOneVertex marks a subset i unavailable when adding a vertex with
       membership containing i would fill a facet past purity p
       (Length[i] == 1) or make all facets in i share p common vertices
       (Length[i] > 1, which would force two facets to coincide).
     * Lex constraint Order[#, last] >= 0 (cheap, bliss) generates each
       labeled complex in exactly one vertex order.
     * Starting states are facetSubsets[[q;;-1]]: the first q-1 singletons
       are equivalent to the kept starts under the lex symmetry.

   BLISS encoding: for a complex c build the bipartite graph G(c) with one
   vertex per vertex of c (1..n), one per facet (n+1..n+q), edges for
   membership, plus a triangle gadget per facet (two tag vertices
   n+q+2(i-1)+1, +2). Bipartite graphs are triangle-free, so every triangle
   contains exactly one facet vertex and no automorphism swaps vertices and
   facets: CanonicalGraph[G(c1)] === CanonicalGraph[G(c2)] iff c1 ~ c2.

   McKay (1998, "Isomorph-free exhaustive generation"): a partial state S is
   accepted iff the just-added vertex is the canonical removal vertex m(S),
   the vertex side node with the largest canonical label in G(S). Strict
   equality (no orbit fallback) gives one canonical augmentation path per
   class per starting state; cross-start duplicates are caught by the BLISS
   key at the leaves. *)


(* ============================================================
   Truth-grid gates
   ============================================================ *)

(* Iso-class counts of the 9 stored truth cells (data/p{p}q{q}_truth.wxf);
   (4,5) also matches ECGrav's NumUnlabeledPureComplexes (Phase 5a). *)
$CombTruthIsoCounts = <|
  {2, 4} -> 11, {2, 5} -> 26, {2, 6} -> 68, {2, 7} -> 177,
  {3, 4} -> 66, {3, 5} -> 445, {3, 6} -> 4279,
  {4, 4} -> 278, {4, 5} -> 5532|>;

$CombResearchSubkernelSetup = Function[ParallelNeeds["ECGrav`"]];


(* ============================================================
   Cheap key + bucketed dedup
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

(* Within-bucket dedupe: same algorithm as ChooseNonIsomorphic's single-list
   overload, restricted to one bucket so the outer scan is small. *)
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

ChooseNonIsomorphicPureComplexesBucketed[allLab_List] := chooseNonIsoBucketed[allLab];


(* ============================================================
   Running the starts, with optional progress reports
   ============================================================ *)

(* Called by the workers at each leaf as $enumerationReport[leaves, keys]
   when it is not None (only inside enumerationReported). *)
$enumerationReport = None;

(* One start with reports: report[i, leaves, keys, done] at most every half
   second, plus once when the start is done. job = {start, index}. *)
enumerationReported[worker_, {start_, i_}, args_List, report_] := Module[
  {last = AbsoluteTime[], r},
  r = Block[{$enumerationReport = Function[{leaves, keys},
      If[AbsoluteTime[] - last > 0.5,
        last = AbsoluteTime[];
        report[i, leaves, keys, 0]]]},
    worker[start, Sequence @@ args]];
  report[i, r["count"], Length[r["map"]], 1];
  r];

(* Subkernels report through small files in a temporary directory (one per
   start), and the master reads them twice a second. Not through a shared
   function: an abort that finds a subkernel inside a shared call breaks its
   link, and Parallel then spends minutes replacing kernels. *)
enumerationFileReport[dir_][i_, leaves_, keys_, done_] := Quiet @ AbortProtect @ Module[
  {s = OpenWrite[FileNameJoin[{dir, ToString[i] <> ".txt"}]]},
  WriteString[s, StringRiffle[{leaves, keys, done}, " "], "\n"];
  Close[s];];

(* file -> {leaves, keys, done}; a file caught while being written is left out *)
enumerationReadReports[dir_] := Select[
  AssociationMap[Quiet[ReadList[#, Number]] &, FileNames["*.txt", dir]],
  MatchQ[{_Integer, _Integer, _Integer}]];

enumerationProgressRow[nStarts_, rows_] := <|"starts" -> nStarts,
  "startsDone" -> Total[rows[[All, 3]]], "leaves" -> Total[rows[[All, 1]]],
  "classesSeen" -> Max[0, rows[[All, 2]]]|>;

(* worker[start, args...] over the starts, results in start order.
   progress: None, or a function called on the master with
   <|"starts", "startsDone", "leaves", "classesSeen"|>. *)
enumerationMap[worker_, starts_List, args_List, par_, None] := If[par,
  ParallelMap[worker[#, Sequence @@ args] &, starts,
    Method -> "FinestGrained", DistributedContexts -> Automatic],
  worker[#, Sequence @@ args] & /@ starts];

enumerationMap[worker_, starts_List, args_List, False, progress_] := Module[
  {rows = <||>, n = Length[starts]},
  MapIndexed[
    enumerationReported[worker, {#1, First[#2]}, args,
      Function[{i, leaves, keys, done},
        rows[i] = {leaves, keys, done};
        progress[enumerationProgressRow[n, Values[rows]]]]] &,
    starts]];

enumerationMap[worker_, starts_List, args_List, True, progress_] := Module[
  {dir = CreateDirectory[], n = Length[starts], rows = <||>, tick, task, result},
  tick[] := (
    rows = Join[rows, enumerationReadReports[dir]];
    If[rows =!= <||>, progress[enumerationProgressRow[n, Values[rows]]]]);
  task = SessionSubmit[ScheduledTask[tick[], Quantity[0.5, "Seconds"]]];
  WithCleanup[
    DistributeDefinitions[enumerationReported, enumerationFileReport];
    result = With[{dir = dir},
      ParallelMap[enumerationReported[worker, #, args, enumerationFileReport[dir]] &,
        MapIndexed[{#1, First[#2]} &, starts],
        Method -> "FinestGrained", DistributedContexts -> Automatic]];
    TaskRemove[task];
    tick[];
    result,
    Quiet[TaskRemove[task]];
    Quiet[DeleteDirectory[dir, DeleteContents -> True]]]];


(* ============================================================
   Cheap enumerator: single-start worker + driver
   ============================================================ *)

(* DFS from one starting vertex membership set v0 with a local bucket map.
   Returns <|"map" -> localMap, "count" -> localCount|>. Pure in
   (v0, p, q, target, facetSubsets) so it can run on subkernels. *)
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
      If[$enumerationReport =!= None,
        $enumerationReport[localCount, Length[localMap]]];
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

(* Merge bucket-rep lists for the same canonical key (Merge combiner). *)
mergeBucketReps[lists_List] := chooseNonIsoBucketWithin[Flatten[lists, 1]];

Options[streamingEnumeratePure] = {"Parallel" -> True, "Progress" -> None};

streamingEnumeratePure[purity_Integer, facetOrder_Integer,
                       OptionsPattern[]] := Module[
  {p = purity, q = facetOrder, target, facetSubsets, starts,
   useParallel = OptionValue["Parallel"],
   localResults, mergedMap, totalEmitted},

  target = p * q;
  facetSubsets = Subsets[Range[q]][[2;;-1]];
  starts = facetSubsets[[q;;-1]];

  If[TrueQ[useParallel],
    (* Subkernels need ECGrav (for IsomorphicSimplicialComplexQ) and the
       canonicalKey + streamingFromStart definitions. *)
    $CombResearchSubkernelSetup[];
    ParallelEvaluate[ClearSystemCache[]];
    DistributeDefinitions[
      canonicalKey, streamingFromStart, chooseNonIsoBucketWithin]];

  localResults = enumerationMap[streamingFromStart, starts,
    {p, q, target, facetSubsets}, TrueQ[useParallel], OptionValue["Progress"]];

  totalEmitted = Total[#["count"] & /@ localResults];
  mergedMap = Merge[#["map"] & /@ localResults, mergeBucketReps];

  <|"isoReps"     -> Flatten[Values[mergedMap], 1],
    "totalEmitted" -> totalEmitted,
    "numBuckets"   -> Length[mergedMap]|>
];


(* ============================================================
   BLISS canonical key
   ============================================================ *)

(* Integer labels (2026-05-13): V-side 1..n, F-side n+1..n+q, T-side
   n+q+1..n+3q. When the vertices are already 1..n (every DFS complex) the
   relabel step is skipped; arbitrary labels are relabeled to 1..n.
   Sort is critical: DeleteDuplicates keeps first-appearance order, and for
   DFS complexes the vertex ids appear in reversed-facet order. Without Sort
   vList === Range[n] fails and the relabel scrambles the vertex labels,
   breaking the McKay predicate's === Length[state] check. *)
bipartiteIncidenceGraph[complex_List] := Module[
  {q, vList, n, fStart, tStart, relabeledFacets, bipEdges, gadgetEdges},
  q = Length[complex];
  vList = Sort @ DeleteDuplicates @ Flatten[complex];
  n = Length[vList];
  relabeledFacets = If[vList === Range[n],
    complex,
    Module[{relabel = AssociationThread[vList -> Range[n]]},
      (relabel /@ #) & /@ complex]];
  fStart = n;
  tStart = n + q;
  bipEdges = Flatten @ Table[
    UndirectedEdge[v, fStart + i],
    {i, q}, {v, relabeledFacets[[i]]}];
  gadgetEdges = Flatten @ Table[
    {UndirectedEdge[fStart + i, tStart + 2 (i - 1) + 1],
     UndirectedEdge[fStart + i, tStart + 2 (i - 1) + 2],
     UndirectedEdge[tStart + 2 (i - 1) + 1, tStart + 2 (i - 1) + 2]},
    {i, q}];
  Graph[Range[n + 3 q], Join[bipEdges, gadgetEdges]]
];

(* Sorted canonical EdgeList rather than the Graph: hashing a Graph walks
   its whole internal representation, which dominated early benchmarks. *)
blissCanonicalKey[complex_List] :=
  Sort @ (List @@@ EdgeList @ CanonicalGraph @
    bipartiteIncidenceGraph[complex]);

PureComplexCanonicalKey[complex_List] := blissCanonicalKey[complex];


(* ============================================================
   BLISS enumerator: single-start worker + driver
   ============================================================ *)

(* Same DFS as streamingFromStart; the emit step keeps ONE representative
   per canonical key (keys are unique by construction). *)
streamingFromStartBLISS[v0_List, p_Integer, q_Integer,
                       target_Integer, facetSubsets_List] := Module[
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
      If[$enumerationReport =!= None,
        $enumerationReport[localCount, Length[localMap]]];
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

Options[streamingEnumeratePureBLISS] = {"Parallel" -> True, "Progress" -> None};

streamingEnumeratePureBLISS[purity_Integer, facetOrder_Integer,
                            OptionsPattern[]] := Module[
  {p = purity, q = facetOrder, target, facetSubsets, starts,
   useParallel = OptionValue["Parallel"],
   localResults, mergedMap, totalEmitted},

  target = p * q;
  facetSubsets = Subsets[Range[q]][[2;;-1]];
  starts = facetSubsets[[q;;-1]];

  If[TrueQ[useParallel],
    (* CanonicalGraph is built in; ECGrav is not needed on the workers. *)
    DistributeDefinitions[
      bipartiteIncidenceGraph, blissCanonicalKey,
      streamingFromStartBLISS]];

  localResults = enumerationMap[streamingFromStartBLISS, starts,
    {p, q, target, facetSubsets}, TrueQ[useParallel], OptionValue["Progress"]];

  totalEmitted = Total[#["count"] & /@ localResults];
  (* A key may appear in several kernels (same class from different
     starts). Pick any rep. *)
  mergedMap = Merge[#["map"] & /@ localResults, First];

  <|"isoReps"      -> Values[mergedMap],
    "totalEmitted" -> totalEmitted,
    "numBuckets"   -> Length[mergedMap]|>
];


(* ============================================================
   McKay canonical augmentation
   ============================================================ *)

(* The vertex-side node of bipartiteIncidenceGraph[cmplx] with the largest
   canonical label (McKay's canonical "last vertex to remove"). Vertex
   labels are 1..n; for DFS states vList === Range[n], so the result equals
   the depth of the just-added vertex when it is canonical. *)
canonicalRemovalVSide[cmplx_List] := Module[
  {g, vList, n, canonG, isoMap, canonPositions, maxPos},
  g = bipartiteIncidenceGraph[cmplx];
  vList = Sort @ DeleteDuplicates @ Flatten[cmplx];
  n = Length[vList];
  canonG = CanonicalGraph[g];
  isoMap = First[FindGraphIsomorphism[g, canonG]];
  canonPositions = Lookup[isoMap, Range[n]];
  maxPos = First[Ordering[canonPositions, -1]];
  vList[[maxPos]]
];

(* Is candidate (a vertex label in 1..n) in the orbit of
   canonicalRemovalVSide[cmplx] under Aut(bipartiteIncidenceGraph[cmplx])?
   The current McKay predicate uses strict equality and never calls this;
   kept for future reformulations. *)
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

streamingFromStartMcKay[v0_List, p_Integer, q_Integer,
                       target_Integer, facetSubsets_List] := Module[
  {localMap, localCount, addOneVertex, convertToFacets, isMcKayValid,
   emit, dfs},
  Block[{$RecursionLimit = Infinity, $IterationLimit = Infinity},
    localMap = <||>;
    localCount = 0;

    (* No lex constraint: lex's canonical choice conflicts with McKay's
       canonical removal vertex. McKay alone enforces canonicity. *)
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

    (* State of size 1 trivially passes. Strict equality: the just-added
       vertex must BE the canonical removal vertex. *)
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
      If[$enumerationReport =!= None,
        $enumerationReport[localCount, Length[localMap]]];
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

Options[streamingEnumeratePureMcKay] = {"Parallel" -> True, "Progress" -> None};

streamingEnumeratePureMcKay[purity_Integer, facetOrder_Integer,
                            OptionsPattern[]] := Module[
  {p = purity, q = facetOrder, target, facetSubsets, starts,
   useParallel = OptionValue["Parallel"],
   localResults, mergedMap, totalEmitted},

  target = p * q;
  facetSubsets = Subsets[Range[q]][[2;;-1]];
  starts = facetSubsets[[q;;-1]];

  If[TrueQ[useParallel],
    DistributeDefinitions[
      bipartiteIncidenceGraph, blissCanonicalKey,
      canonicalRemovalVSide, isInCanonicalRemovalOrbit,
      streamingFromStartMcKay]];

  localResults = enumerationMap[streamingFromStartMcKay, starts,
    {p, q, target, facetSubsets}, TrueQ[useParallel], OptionValue["Progress"]];

  totalEmitted = Total[#["count"] & /@ localResults];
  mergedMap = Merge[#["map"] & /@ localResults, First];

  <|"isoReps"      -> Values[mergedMap],
    "totalEmitted" -> totalEmitted,
    "numBuckets"   -> Length[mergedMap]|>
];


(* ============================================================
   Public entry point
   ============================================================ *)

enumerationMethod[Automatic, p_Integer, _] := If[p >= 4, "McKay", "Cheap"];
enumerationMethod[m_String, _, _] /; MemberQ[{"Cheap", "BLISS", "McKay"}, m] := m;
enumerationMethod[m_String, p_, q_] /;
    MemberQ[{"cheap", "bliss", "mckay"}, ToLowerCase[m]] :=
  enumerationMethod[ToLowerCase[m] /. {"cheap" -> "Cheap", "bliss" -> "BLISS",
    "mckay" -> "McKay"}, p, q];
enumerationMethod[m_, _, _] := $Failed;

Options[EnumerateUnlabeledPureComplexes] = {Method -> Automatic, "Parallel" -> True,
  "Progress" -> None};

EnumerateUnlabeledPureComplexes[p_Integer?Positive, q_Integer?Positive,
    OptionsPattern[]] := Module[{m, par = TrueQ[OptionValue["Parallel"]],
    prog = OptionValue["Progress"]},
  m = enumerationMethod[OptionValue[Method], p, q];
  If[m === $Failed,
    Message[EnumerateUnlabeledPureComplexes::method, OptionValue[Method]];
    Return[$Failed]];
  Append[
    Switch[m,
      "Cheap", streamingEnumeratePure[p, q, "Parallel" -> par, "Progress" -> prog],
      "BLISS", streamingEnumeratePureBLISS[p, q, "Parallel" -> par, "Progress" -> prog],
      "McKay", streamingEnumeratePureMcKay[p, q, "Parallel" -> par, "Progress" -> prog]],
    "method" -> m]];
