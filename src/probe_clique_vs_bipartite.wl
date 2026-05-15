(* probe_clique_vs_bipartite.wl
   Investigates Betre's McKay-on-clique-complexes suggestion. Times two
   canonicalization paths on representative pure simplicial complexes:

   Path A (CURRENT McKay): bipartiteIncidenceGraph + CanonicalGraph +
     FindGraphIsomorphism. Bipartite graph has numV + 3q vertices,
     numV*p + 3q edges. Triangle-gadget side-distinguishing trick.

   Path B (BETRE's suggestion): cliqueGraph (1-skeleton) + CanonicalGraph +
     FindGraphIsomorphism. Simpler graph with numV vertices and at most
     C(p,2)*q edges. Lossy: two non-iso simplicial complexes can have
     the same 1-skeleton (faces vs sub-cliques distinction). So Path B
     is a CHEAPER UPPER-BOUND iso check, not a full one — same as ECGrav's
     IsomorphicSimplicialComplexQ uses internally (clique-iso first, then
     facet-equality verify).

   What we want to learn:
     1. How much faster is Path B per call?
     2. Could we use Path B's canonical-removal vertex inside McKay's
        canonical-augmentation predicate?
     3. If Path B is faster but lossy: hybrid scheme (use clique key as
        a cheap pre-filter, run bipartite only when needed)?
*)

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator_bliss.wl"}]];

(* The 1-skeleton: vertex-set = all distinct vertices in the facets;
   edge-set = all pairs in any facet (i.e., the union of clique edges). *)
cliqueGraph[complex_List] := Module[
  {vList, n, fStart, relabel, relabeledFacets, edges},
  vList = Sort @ DeleteDuplicates @ Flatten[complex];
  n = Length[vList];
  relabeledFacets = If[vList === Range[n],
    complex,
    Module[{rl = AssociationThread[vList -> Range[n]]},
      (rl /@ #) & /@ complex]];
  edges = UndirectedEdge @@@ DeleteDuplicates[
    Flatten[Subsets[#, {2}] & /@ relabeledFacets, 1]];
  Graph[Range[n], edges]
];

testComplexes = {
  {"(p=2) 3-edge path",       {{1, 2}, {2, 3}, {3, 4}}},
  {"(p=2) 4 disjoint edges",  {{1, 2}, {3, 4}, {5, 6}, {7, 8}}},
  {"(p=3) 2 triangles share", {{1, 2, 3}, {1, 2, 4}}},
  {"(p=3) 4 triangles tetra", {{1, 2, 3}, {1, 2, 4}, {1, 3, 4}, {2, 3, 4}}},
  {"(p=3) 4 disjoint tri",    {{1,2,3}, {4,5,6}, {7,8,9}, {10,11,12}}},
  {"(p=4) 5 tetra max-V",     {{1,2,3,4},{5,6,7,8},{9,10,11,12},
                               {13,14,15,16},{17,18,19,20}}},
  {"(p=4) 5 tetra share v",   {{1,2,3,4},{1,5,6,7},{1,8,9,10},
                               {1,11,12,13},{1,14,15,16}}}
};

timePer[label_, expr_Hold, n_] := Module[{t, us},
  t = First @ AbsoluteTiming[Do[ReleaseHold[expr], {n}]];
  us = N[1.0*^6 * t / n];
  Print["    ", StringPadRight[label, 36], Round[us, 0.1], " us"];
  us];

reps = 200;

Do[
  Module[{name = item[[1]], cmplx = item[[2]],
          gBip, cgBip, gClq, cgClq,
          tBipBuild, tBipCanon, tBipFind, tBipTotal,
          tClqBuild, tClqCanon, tClqFind, tClqTotal,
          speedup},
    Print["----- ", name, " : ", cmplx, " -----"];

    gBip  = bipartiteIncidenceGraph[cmplx];  cgBip = CanonicalGraph[gBip];
    gClq  = cliqueGraph[cmplx];              cgClq = CanonicalGraph[gClq];

    Print["    |V(bipartite)| = ", VertexCount[gBip],
          ",  |E(bipartite)| = ", EdgeCount[gBip]];
    Print["    |V(clique)|    = ", VertexCount[gClq],
          ",  |E(clique)|    = ", EdgeCount[gClq]];

    tBipBuild = timePer["bipartite: build",
      Hold[bipartiteIncidenceGraph[cmplx]], reps];
    tBipCanon = timePer["bipartite: CanonicalGraph",
      Hold[CanonicalGraph[gBip]], reps];
    tBipFind  = timePer["bipartite: FindGraphIsomorphism",
      Hold[First[FindGraphIsomorphism[gBip, cgBip]]], reps];
    tBipTotal = tBipBuild + tBipCanon + tBipFind;

    tClqBuild = timePer["clique:    build",
      Hold[cliqueGraph[cmplx]], reps];
    tClqCanon = timePer["clique:    CanonicalGraph",
      Hold[CanonicalGraph[gClq]], reps];
    tClqFind  = timePer["clique:    FindGraphIsomorphism",
      Hold[First[FindGraphIsomorphism[gClq, cgClq]]], reps];
    tClqTotal = tClqBuild + tClqCanon + tClqFind;

    speedup = tBipTotal / tClqTotal;
    Print["    -> bipartite total: ", Round[tBipTotal, 0.1], " us"];
    Print["    -> clique total:    ", Round[tClqTotal, 0.1], " us"];
    Print["    -> speedup of clique over bipartite: ",
      Round[speedup, 0.01], "x"];
    Print[""];
  ],
  {item, testComplexes}];

Print["done."];
