(* pure_simplicial_compute.wl
   Sampling + per-sample statistics pipeline for Figures 3-16.
   Pure simplicial complexes, q = 10, p in {2, 3, 4}.
   Produces one CSV per p with all statistics and reweighting weights.
   Independent of histograms_handoff_v2.nb / histograms_paper_figures.nb. *)

Needs["ECGrav`"];

(* ===== Parameters ===== *)
qVal = 10;
pList = If[ValueQ[pListOverride], pListOverride, {2, 3, 4}];
sampleSize = If[ValueQ[sampleSizeOverride], sampleSizeOverride, 10000];
randomSeed = 123456;

(* Output goes to projectRoot/data/  (projectRoot = parent of src/). *)
scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
outputDir = FileNameJoin[{projectRoot, "data"}];
If[!DirectoryQ[outputDir], CreateDirectory[outputDir]];

(* Optional ParallelMap over the per-sample stats step.
   Activate by setting useParallelOverride = True before Get'ing this script. *)
useParallel = If[ValueQ[useParallelOverride], useParallelOverride, False];

Print["sampleSize  = ", sampleSize];
Print["pList       = ", pList];
Print["outputDir   = ", outputDir];
Print["useParallel = ", useParallel];

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

(* ===== Parallel kernel setup (only when useParallel=True) ===== *)
If[useParallel,
  Print["launching parallel kernels ..."];
  LaunchKernels[];
  Print["  ", Length[Kernels[]], " kernels active"];
  ParallelEvaluate[Needs["ECGrav`"]];
  DistributeDefinitions[oneSkeleton, kPathComps, simplicesOfDim,
    boundaryMatrix, bettiNumber, statsFor, qVal]];

(* ===== Main loop with checkpointing =====
   Per-p chunk files `..._chunk_k.csv` are written atomically (tmp + rename).
   On restart we skip any p whose final CSV exists, and for a partially-done p
   we resume at the first missing chunk. At most one chunk (~17 min on p=4)
   is redone after a crash. *)

headers = {"numV", "aut", "autF", "connected",
  "num1VConnComps", "num2VConnComps", "largestCompRatio",
  "num2PathConnComps", "num3PathConnComps",
  "Betti1", "Betti2", "Betti3",
  "wVertex", "wUnlabeled", "wFacet"};

chunkSize = If[ValueQ[chunkSizeOverride], chunkSizeOverride, 25000];
numChunks = Ceiling[sampleSize / chunkSize];
chunkSizeFor[k_] := If[k == numChunks,
  sampleSize - (numChunks - 1) * chunkSize, chunkSize];

baseStem[p_] := "p" <> ToString[p] <> "q" <> ToString[qVal] <>
  "_n" <> ToString[sampleSize];
chunkFile[p_, k_] := FileNameJoin[{outputDir,
  baseStem[p] <> "_chunk_" <> ToString[k] <> ".csv"}];
finalFile[p_] := FileNameJoin[{outputDir,
  baseStem[p] <> "_samples.csv"}];

firstMissingChunk[p_] := Module[{k = 1},
  While[k <= numChunks && FileExistsQ[chunkFile[p, k]], k++]; k];

exportChunkAtomic[p_, k_, rowsWithHeader_] := Module[{tmp, final, res},
  tmp = chunkFile[p, k] <> ".tmp";
  final = chunkFile[p, k];
  Export[tmp, rowsWithHeader, "CSV"];
  If[! FileExistsQ[tmp],
    Print["    ERROR: tmp file not written: ", tmp]; Abort[]];
  If[FileExistsQ[final], DeleteFile[final]];
  res = RenameFile[tmp, final];
  If[res === $Failed,
    Print["    ERROR: rename failed ", tmp, " -> ", final]; Abort[]]];

consolidateChunks[p_] := Module[{allRows, final},
  allRows = Flatten[Rest /@ (Import[chunkFile[p, #], "CSV"] & /@ Range[numChunks]), 1];
  final = finalFile[p];
  Export[final, Prepend[allRows, headers]];
  Do[DeleteFile[chunkFile[p, k]], {k, numChunks}];
  Print["  consolidated ", Length[allRows], " rows → ", FileNameTake[final]];
  allRows];

reportESS[p_, allRows_] := Module[{numVs, auts, autFs, wU, wF, essU, essF},
  numVs = allRows[[All, 1]];
  auts  = allRows[[All, 2]];
  autFs = allRows[[All, 3]];
  wU = MapThread[#1 / #2! &, {auts, numVs}];
  wF = MapThread[#1 * qVal! / (#2 * #3!) &, {auts, autFs, numVs}];
  essU = N[Total[wU]^2 / Total[wU^2]];
  essF = N[Total[wF]^2 / Total[wF^2]];
  Print["  ESS unlabeled: ", Round[essU], " / ", sampleSize,
    " (", ToString[NumberForm[100. essU / sampleSize, {4, 2}]], "%)"];
  Print["  ESS facet    : ", Round[essF], " / ", sampleSize,
    " (", ToString[NumberForm[100. essF / sampleSize, {4, 2}]], "%)"]];

Do[
  Print["-----------------------------------------"];
  Print["p = ", p, ", q = ", qVal, ", N = ", sampleSize,
    ", chunkSize = ", chunkSize, ", numChunks = ", numChunks];

  If[FileExistsQ[finalFile[p]],
    Print["  final CSV already present — skipping p = ", p],
   (* else *)
    Module[{startK = firstMissingChunk[p]},
      If[startK > 1, Print["  resuming at chunk ", startK, " / ", numChunks]];

      Do[
        Module[{thisN = chunkSizeFor[k], tSample, tStats, sample,
                statsRows, numVs, auts, autFs, wV, wU, wF, rows},
          Print["  chunk ", k, "/", numChunks, " (n=", thisN, ")"];
          SeedRandom[randomSeed + p*1000 + k];

          tSample = First @ AbsoluteTiming[
            sample = RandomVertexLabeledPureSimplicialComplex[{p, qVal}, thisN]];
          Print["    sampling : ", tSample, " s"];

          tStats = First @ AbsoluteTiming[
            statsRows = If[useParallel,
              ParallelMap[statsFor[#, p] &, sample],
              statsFor[#, p] & /@ sample]];
          Print["    stats    : ", tStats, " s"];

          numVs = statsRows[[All, 1]];
          auts  = statsRows[[All, 2]];
          autFs = statsRows[[All, 3]];
          wV = ConstantArray[1, thisN];
          wU = MapThread[#1 / #2! &, {auts, numVs}];
          wF = MapThread[#1 * qVal! / (#2 * #3!) &, {auts, autFs, numVs}];
          rows = MapThread[Join[#1, {#2, #3, #4}] &, {statsRows, wV, wU, wF}];

          exportChunkAtomic[p, k, Prepend[rows, headers]];
          Print["    wrote chunk file"]],
        {k, startK, numChunks}];

      reportESS[p, consolidateChunks[p]]]],
  {p, pList}];

Print["-----------------------------------------"];
Print["Done."];
