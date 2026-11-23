(* ::Package:: *)

(* Statistics.wl: the 12 per-complex statistics every sampler and the truth
   stage record. Loaded by Kernel/CombResearch.wl into CombResearch`Private`;
   the public symbols are declared there.

   Moved verbatim in Phase 4 from src/lib_stats.wl (itself moved verbatim
   from pure_simplicial_compute.wl in Phase 2; deleted in Phase 5). The functions and
   the column order are unchanged, so existing WXFs stay comparable. *)

$PureComplexStatisticNames = {"numV", "aut", "autF", "connected",
  "num1VConnComps", "num2VConnComps", "largestCompRatio",
  "num2PathConnComps", "num3PathConnComps",
  "Betti1", "Betti2", "Betti3"};

(* ===== 1-skeleton ===== *)
oneSkeleton[c_List] := Module[{verts, edges},
  verts = DeleteDuplicates[Flatten[c]];
  edges = DeleteDuplicates[Sort /@ Flatten[Subsets[#, {2}] & /@ c, 1]];
  Graph[verts, UndirectedEdge @@@ edges]
];

(* ===== k-path components via k-graph construction =====
   Vertices = (k-1)-simplices (size-k subsets of facets).
   Edges between two (k-1)-simplices in any common facet.
   Number of k-path connected components = #connected components of k-graph. *)
kPathComps[c_List, k_Integer] := Module[{faces, edges},
  faces = DeleteDuplicates[Sort /@ Flatten[Subsets[#, {k}] & /@ c, 1]];
  edges = DeleteDuplicates[
    Flatten[Subsets[Sort /@ Subsets[#, {k}], {2}] & /@ c, 1]];
  Length[ConnectedComponents[Graph[faces, UndirectedEdge @@@ edges]]]
];

(* ===== Betti numbers over Z_2 =====
   For a pure complex given by its facets:
     C_k spanned by the distinct k-simplices (size-(k+1) subsets of facets)
     boundary d_k : C_k -> C_{k-1} sends a k-simplex to sum of its codim-1 faces
     beta_k = dim C_k - rank d_k - rank d_{k+1}  (mod 2 coefficients) *)
simplicesOfDim[c_List, k_Integer] :=
  DeleteDuplicates[Sort /@ Flatten[Subsets[#, {k + 1}] & /@ c, 1]];

boundaryMatrix[kSimps_List, km1Simps_List] := Module[{idx, entries},
  If[kSimps === {} || km1Simps === {},
    Return[SparseArray[{}, {Length[km1Simps], Max[Length[kSimps], 1]}]]];
  idx = AssociationThread[km1Simps -> Range[Length[km1Simps]]];
  entries = Flatten[Table[
    With[{s = kSimps[[i]]},
      Table[{idx[Sort[Delete[s, j]]], i} -> 1, {j, Length[s]}]],
    {i, Length[kSimps]}], 1];
  SparseArray[entries, {Length[km1Simps], Length[kSimps]}]
];

bettiNumber[c_List, k_Integer] := Module[{ck, ckm1, ckp1, rk, rkp1},
  ck = simplicesOfDim[c, k];
  If[Length[ck] == 0, Return[0]];
  ckm1 = If[k == 0, {}, simplicesOfDim[c, k - 1]];
  ckp1 = simplicesOfDim[c, k + 1];
  rk = If[k == 0 || Length[ckm1] == 0, 0,
    MatrixRank[boundaryMatrix[ck, ckm1], Modulus -> 2]];
  rkp1 = If[Length[ckp1] == 0, 0,
    MatrixRank[boundaryMatrix[ckp1, ck], Modulus -> 2]];
  Length[ck] - rk - rkp1
];

(* ===== Per-sample bundle =====
   Returns a fixed-length row; path-k and Betti_k unavailable at given p are "" (empty). *)
statsFor[c_List, p_Integer] := Module[
  {g, nv, aut, autF, conn, n1v, n2v, lcr, isConn, n2p, n3p, b1, b2, b3},
  g = oneSkeleton[c];
  nv = VertexCount[g];
  aut = PureComplexAutomorphismGroupOrder[c];
  autF = PureComplexFacetAutomorphismGroupOrder[c];
  conn = ConnectedComponents[g];
  n1v = Length[conn];
  n2v = Length[KVertexConnectedComponents[g, 2]];
  lcr = N[Max[Length /@ conn] / nv];
  isConn = If[n1v == 1, 1, 0];
  n2p = If[p >= 3, kPathComps[c, 2], ""];
  n3p = If[p >= 4, kPathComps[c, 3], ""];
  b1 = bettiNumber[c, 1];
  b2 = If[p >= 3, bettiNumber[c, 2], ""];
  b3 = If[p >= 4, bettiNumber[c, 3], ""];
  {nv, aut, autF, isConn, n1v, n2v, lcr, n2p, n3p, b1, b2, b3}
];

(* ===== Public names ===== *)
PureComplexStatistics[c_List, p_Integer] := statsFor[c, p];
PureComplexStatistics[c_List] /; c =!= {} := statsFor[c, Length[First[c]]];
PureComplexKPathComponents[c_List, k_Integer?Positive] := kPathComps[c, k];
PureComplexBettiNumber[c_List, k_Integer?NonNegative] := bettiNumber[c, k];
