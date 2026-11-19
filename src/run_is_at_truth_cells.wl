(* run_is_at_truth_cells.wl
   Draw vertex-labeled IS samples at (3,5) and (4,5) and aggregate into
   per-target numV histograms matching the q=10 hist schema. Lets us
   compare IS against MH and truth at cells where all three exist.

   Only computes {numV, |Aut|, |Aut_F|} per sample — full statsFor is
   unnecessary here (we only marginalize on numV). Weights:
     wVertex    = 1
     wUnlabeled = |Aut| / numV!
     wFacet     = |Aut| * q! / (|Aut_F| * numV!)

   Chunked sampling + ParallelMap on the stats step; flushes progress
   per chunk so we can see it move.

   Output:
     data/p{p}q{q}_is_{target}_numv_hist.wxf

   Env:
     COMB_IS_CELLS = "p,q;p,q;..."  (default "3,5;4,5")
     COMB_IS_N     = integer        (default 100000)
     COMB_IS_CHUNK = integer        (default 5000)
     COMB_IS_SEED  = integer        (default 42)
     COMB_IS_PAR   = 1|0            (default 1; ParallelMap on stats)
     COMB_FORCE    = 1              overwrite existing hists
*)

(* Always read/write to the canonical main checkout data dir, since
   truth/MH WXFs and the q=10 IS hists live there. *)
dataDir = "C:/CombResearch/data";

Get[FileNameJoin[{DirectoryName[$InputFileName], "load_ecgrav.wl"}]];

parseEnvCells[s_String] := Module[{pairs},
  pairs = StringSplit[StringTrim[s], ";"];
  pairs = StringSplit[#, ","] & /@ pairs;
  ToExpression /@ # & /@ pairs];

cells = With[{e = Environment["COMB_IS_CELLS"]},
  If[StringQ[e] && StringLength[e] > 0, parseEnvCells[e],
    {{3, 5}, {4, 5}}]];
nSamples = With[{e = Environment["COMB_IS_N"]},
  If[StringQ[e] && StringLength[e] > 0, ToExpression[e], 100000]];
chunkSize = With[{e = Environment["COMB_IS_CHUNK"]},
  If[StringQ[e] && StringLength[e] > 0, ToExpression[e], 5000]];
seed = With[{e = Environment["COMB_IS_SEED"]},
  If[StringQ[e] && StringLength[e] > 0, ToExpression[e], 42]];
useParallel = With[{e = Environment["COMB_IS_PAR"]},
  !(StringQ[e] && e === "0")];
forceRecompute = With[{e = Environment["COMB_FORCE"]},
  StringQ[e] && e === "1"];

Print["dataDir     = ", dataDir];
Print["cells       = ", cells];
Print["nSamples    = ", nSamples];
Print["chunkSize   = ", chunkSize];
Print["useParallel = ", useParallel];
Print["seed        = ", seed];
Print["force       = ", forceRecompute];

If[useParallel,
  Print["launching parallel kernels..."];
  LaunchKernels[];
  Print["  ", Length[Kernels[]], " kernels active"];
  combLoadECGravOnKernels[]];

oneSkeleton[c_List] := Graph[Union @@ (Subsets[#, {2}] & /@ c)];

statRow[c_] := {
  VertexCount[oneSkeleton[c]],
  PureComplexAutomorphismGroupOrder[c],
  PureComplexFacetAutomorphismGroupOrder[c]};

If[useParallel, DistributeDefinitions[oneSkeleton, statRow]];

isFile[p_, q_, t_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <>
  "_is_" <> t <> "_numv_hist.wxf"}];

processOne[p_, q_] := Module[
  {outFiles, targets, allExist, numChunks, sizeFor,
   allNumVs, allAuts, allAutFs, t0, tSamp, tStat, sample, rows, k,
   numVs, auts, autFs, qFact, weights, ess, hist, frac, total,
   thisSize},
  targets = {"vertex", "unlabeled", "facet"};
  outFiles = AssociationMap[isFile[p, q, #] &, targets];
  allExist = AllTrue[Values[outFiles],
    FileExistsQ[#] && FileByteCount[#] > 0 &];
  If[allExist && !forceRecompute,
    Print["  skip: hists already exist for (", p, ",", q, ")"];
    Return[]];

  Print[""];
  Print["==== (p,q) = (", p, ",", q, ")  N=", nSamples, "  ===="];

  numChunks = Ceiling[nSamples / chunkSize];
  sizeFor[k_] := If[k == numChunks,
    nSamples - (numChunks - 1) * chunkSize, chunkSize];

  allNumVs = {}; allAuts = {}; allAutFs = {};
  Do[
    thisSize = sizeFor[k];
    SeedRandom[seed + p*1000 + q*100 + k];
    t0 = AbsoluteTime[];
    sample = RandomVertexLabeledPureSimplicialComplex[{p, q}, thisSize];
    tSamp = AbsoluteTime[] - t0;
    t0 = AbsoluteTime[];
    rows = If[useParallel,
      ParallelMap[statRow, sample],
      statRow /@ sample];
    tStat = AbsoluteTime[] - t0;
    allNumVs = Join[allNumVs, rows[[All, 1]]];
    allAuts  = Join[allAuts,  rows[[All, 2]]];
    allAutFs = Join[allAutFs, rows[[All, 3]]];
    Print["  chunk ", k, "/", numChunks,
      "  n=", thisSize,
      "  samp=", Round[tSamp, 0.01], "s",
      "  stat=", Round[tStat, 0.01], "s",
      "  cum=", Length[allNumVs]],
    {k, 1, numChunks}];

  qFact = q!;
  Do[
    weights = Switch[t,
      "vertex",    ConstantArray[1., Length[allNumVs]],
      "unlabeled", N @ MapThread[#1 / #2! &, {allAuts, allNumVs}],
      "facet",     N @ MapThread[#1 * qFact / (#2 * #3!) &,
                                 {allAuts, allAutFs, allNumVs}]];
    ess = Total[weights]^2 / Total[weights^2];
    hist = Total /@ GroupBy[Transpose[{allNumVs, weights}], First -> Last];
    total = Total[Values[hist]];
    frac = KeySort @ AssociationThread[Keys[hist] -> Values[hist]/total];
    Print["  target=", t, "  ESS=", NumberForm[ess, 5],
      "  bins=", Length[frac]];
    Export[outFiles[t], <|"p" -> p, "q" -> q, "target" -> t,
      "sourceN" -> Length[allNumVs], "ESS" -> ess,
      "fracHist" -> frac, "seed" -> seed|>, "WXF"];
    Print["    wrote ", FileNameTake[outFiles[t]]],
    {t, targets}]];

Do[processOne @@ cell, {cell, cells}];

Print[""];
Print["Done."];
