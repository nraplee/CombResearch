(* pure_simplicial_compute.wl
   Sampling + per-sample statistics pipeline for Figures 3-16.
   Pure simplicial complexes, q = 10, p in {2, 3, 4}.
   Produces two WXF files per p per session:
     {stem}_stats.wxf     — Association with headers, rows, metadata (stats + weights)
     {stem}_complexes.wxf — Association with the raw sampled complexes
   Independent of histograms_handoff_v2.nb / histograms_paper_figures.nb. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "load_ecgrav.wl"}]];

(* ===== Parameters ===== *)
qVal = 10;
pList = If[ValueQ[pListOverride], pListOverride, {2, 3, 4}];
sampleSize = If[ValueQ[sampleSizeOverride], sampleSizeOverride, 10000];
randomSeed = 123456;

(* ===== Optional fixed-numV mode (Betre, 2026-05-05) =====
   When nnFixed is set, sampling uses the 3-arg form
     RandomVertexLabeledPureSimplicialComplex[{p, qVal, nnFixed}, thisN]
   which conditions on numV = nnFixed. The reweighting weights become
   constants across samples (same numV ⇒ same denominators), so the
   ESS heavy-tail at q=10 disappears. Bars produced are CONDITIONAL
   probabilities π(· | numV = nnFixed), not the marginal.
   The 3-arg form is absent from ECGrav 1.0.0 (COMB_ECGRAV_VERSION=1.0.0). *)
nnFixed = If[ValueQ[nnFixedOverride], nnFixedOverride,
  With[{e = Environment["COMB_NN_FIXED"]},
    If[StringQ[e] && StringLength[e] > 0, ToExpression[e], None]]];

(* Optional run tag. When set (e.g. via env var COMB_RUNTAG="batch2") the output
   filename becomes p{p}q10_n{N}_{runTag}_samples.csv AND the per-chunk seed is
   offset by a deterministic hash of the tag. This lets a fresh run produce
   fully independent samples that can be concatenated with a prior run via
   concat_samples.wl, without colliding on seeds. *)
runTag = If[ValueQ[runTagOverride], runTagOverride,
  With[{envTag = Environment["COMB_RUNTAG"]},
    If[StringQ[envTag] && StringLength[envTag] > 0, envTag, ""]]];
runSeedOffset = If[runTag === "", 0,
  Mod[Hash[runTag, "MD5"], 10^7]];

(* Output goes to $CombDataDir (main checkout data/, see comb_paths.wl). *)
scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
Get[FileNameJoin[{scriptDir, "comb_paths.wl"}]];
outputDir = $CombDataDir;
If[!DirectoryQ[outputDir], CreateDirectory[outputDir]];

(* Optional ParallelMap over the per-sample stats step.
   Activate by setting useParallelOverride = True before Get'ing this script. *)
useParallel = If[ValueQ[useParallelOverride], useParallelOverride, False];

Print["sampleSize    = ", sampleSize];
Print["pList         = ", pList];
Print["nnFixed       = ", If[nnFixed === None, "(none, variable n)", nnFixed]];
Print["outputDir     = ", outputDir];
Print["useParallel   = ", useParallel];
Print["runTag        = ", If[runTag === "", "(none)", runTag]];
Print["runSeedOffset = ", runSeedOffset];

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
  combLoadECGravOnKernels[];
  DistributeDefinitions[oneSkeleton, kPathComps, simplicesOfDim,
    boundaryMatrix, bettiNumber, statsFor, qVal]];

(* ===== Main loop with checkpointing =====
   Per-p chunk files `..._chunk_k_{stats,complexes}.wxf` are written atomically
   (tmp + rename). A chunk is "done" only when BOTH files are present.
   On restart we skip any p whose final stats WXF exists; for a partially-done
   p we resume at the first chunk missing either file. At most one chunk
   (~11 min on p=4) is redone after a crash. *)

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
  "_n" <> ToString[sampleSize] <>
  If[nnFixed === None, "", "_nn" <> ToString[nnFixed]] <>
  If[runTag === "", "", "_" <> runTag];
chunkStatsFile[p_, k_] := FileNameJoin[{outputDir,
  baseStem[p] <> "_chunk_" <> ToString[k] <> "_stats.wxf"}];
chunkComplexesFile[p_, k_] := FileNameJoin[{outputDir,
  baseStem[p] <> "_chunk_" <> ToString[k] <> "_complexes.wxf"}];
finalStatsFile[p_] := FileNameJoin[{outputDir,
  baseStem[p] <> "_stats.wxf"}];
finalComplexesFile[p_] := FileNameJoin[{outputDir,
  baseStem[p] <> "_complexes.wxf"}];

firstMissingChunk[p_] := Module[{k = 1},
  While[k <= numChunks &&
      FileExistsQ[chunkStatsFile[p, k]] &&
      FileExistsQ[chunkComplexesFile[p, k]],
    k++]; k];

exportWxfAtomic[path_String, expr_] := Module[{tmp, res},
  tmp = path <> ".tmp";
  If[FileExistsQ[tmp], DeleteFile[tmp]];
  Export[tmp, expr, "WXF"];
  If[! FileExistsQ[tmp],
    Print["    ERROR: tmp file not written: ", tmp]; Abort[]];
  If[FileExistsQ[path], DeleteFile[path]];
  res = RenameFile[tmp, path];
  If[res === $Failed,
    Print["    ERROR: rename failed ", tmp, " -> ", path]; Abort[]]];

(* Per-chunk files hold bare lists — the Association wrapper with metadata is
   only applied at the final consolidated file. *)
exportChunkAtomic[p_, k_, sample_, rows_] := (
  exportWxfAtomic[chunkStatsFile[p, k], rows];
  exportWxfAtomic[chunkComplexesFile[p, k], sample]);

consolidateChunks[p_] := Module[{allRows, allComplexes, n, statsAssoc, complexesAssoc},
  allRows      = Join @@ (Import[chunkStatsFile[p, #], "WXF"] & /@ Range[numChunks]);
  allComplexes = Join @@ (Import[chunkComplexesFile[p, #], "WXF"] & /@ Range[numChunks]);
  n = Length[allRows];
  statsAssoc = <|
    "headers"   -> headers,
    "rows"      -> allRows,
    "p"         -> p,
    "q"         -> qVal,
    "n"         -> n,
    "runTag"    -> runTag,
    "createdAt" -> DateString[]|>;
  complexesAssoc = <|
    "complexes" -> allComplexes,
    "p"         -> p,
    "q"         -> qVal,
    "n"         -> n,
    "runTag"    -> runTag,
    "createdAt" -> DateString[]|>;
  exportWxfAtomic[finalStatsFile[p],     statsAssoc];
  exportWxfAtomic[finalComplexesFile[p], complexesAssoc];
  Do[
    DeleteFile[chunkStatsFile[p, k]];
    DeleteFile[chunkComplexesFile[p, k]],
    {k, numChunks}];
  Print["  consolidated ", n, " rows → ",
    FileNameTake[finalStatsFile[p]], " + ",
    FileNameTake[finalComplexesFile[p]]];
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

  If[FileExistsQ[finalStatsFile[p]] && FileExistsQ[finalComplexesFile[p]],
    Print["  final WXF files already present — skipping p = ", p],
   (* else *)
    Module[{startK = firstMissingChunk[p]},
      If[startK > 1, Print["  resuming at chunk ", startK, " / ", numChunks]];

      Do[
        Module[{thisN = chunkSizeFor[k], tSample, tStats, sample,
                statsRows, numVs, auts, autFs, wV, wU, wF, rows},
          Print["  chunk ", k, "/", numChunks, " (n=", thisN, ")"];
          SeedRandom[randomSeed + runSeedOffset + p*1000 + k];

          tSample = First @ AbsoluteTiming[
            sample = RandomVertexLabeledPureSimplicialComplex[
              If[nnFixed === None, {p, qVal}, {p, qVal, nnFixed}],
              thisN]];
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

          exportChunkAtomic[p, k, sample, rows];
          Print["    wrote chunk files"]],
        {k, startK, numChunks}];

      reportESS[p, consolidateChunks[p]]]],
  {p, pList}];

Print["-----------------------------------------"];
Print["Done."];
