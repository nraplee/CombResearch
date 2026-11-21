(* render_fig2.wl
   Figure 2 of the paper (p=3, q=3) as a script (Phase 3). It reproduces
   src/reference/histograms_handoff_v2.nb (the distributions) and
   src/reference/histograms_paper_figures.nb (the four panels), which stay
   untouched as the reference. Differences from the notebooks:
     - ECGrav through load_ecgrav.wl (the notebooks used the global paclet);
     - outputs through comb_paths/lib_names/lib_io, not the front end's
       Directory[]: one data file with every distribution and a manifest,
       and the panels under figures/fig2/;
     - no CSVs: the WXF holds the same tables.
   Same computation, in the same order: SeedRandom[123456], all facet-labeled
   complexes, ChooseNonIsomorphicSimplicialComplexes, classes ordered by
   decreasing n!/|Aut|, N vertex-labeled samples, unlabeled and facet
   distributions by reweighting (paper Eqs. 24, 25), exact facet
   enumeration as a check of q!/|Aut_F|. Never RandomFacetLabeled...

   The seeded draws differ from the notebook's: ECGrav's sampler changed
   since (speedups change seeded draws, not the distribution). The exact
   parts (class table, theory distributions, enumeration) must match the
   notebook exactly; tests/fig2_check.wl compares both.

   Env (lib_config): COMB_FIG2_N (10000), COMB_FIG2_SEED (123456),
   COMB_FORCE=1 to overwrite.
   Output: data/p3q3_n{N}_fig2.wxf, figures/fig2/p3q3_n{N}_fig2_combined.{pdf,png}
   and one PDF per panel.

     wolframscript -file src\render_fig2.wl *)

scriptDir = DirectoryName[$InputFileName];
Get[FileNameJoin[{scriptDir, "comb_paths.wl"}]];
Get[FileNameJoin[{scriptDir, "lib_names.wl"}]];
Get[FileNameJoin[{scriptDir, "lib_config.wl"}]];
Get[FileNameJoin[{scriptDir, "lib_io.wl"}]];
Get[FileNameJoin[{scriptDir, "load_ecgrav.wl"}]];

(* ===== Parameters (histograms_handoff_v2.nb, "Parameters") ===== *)
pq = {3, 3};
sampleSize = combSetting["COMB_FIG2_N", 10000, "expr"];
randomSeed = combSetting["COMB_FIG2_SEED", 123456, "expr"];
forceRecompute = combSetting["COMB_FORCE", False, "flag"];
q = pq[[2]];
baseName = "p" <> ToString[pq[[1]]] <> "q" <> ToString[q] <> "_n" <> ToString[sampleSize];
dataFile = combFile["fig2", pq[[1]], q, sampleSize];
figDir = FileNameJoin[{$CombFiguresDir, "fig2"}];
combinedPdf = FileNameJoin[{figDir, baseName <> "_fig2_combined.pdf"}];

Print["render_fig2: p=", pq[[1]], " q=", q, " N=", sampleSize, " seed=", randomSeed,
  "  ECGrav ", $CombECGravVersion];
If[FileExistsQ[dataFile] && FileExistsQ[combinedPdf] && !forceRecompute,
  Print["  outputs exist (", FileNameTake[dataFile], ", ", FileNameTake[combinedPdf],
    "); COMB_FORCE=1 to redo"]; Exit[0]];

SeedRandom[randomSeed];

(* ===== Helper functions (notebook, "Helper Functions") ===== *)
numVert[cmplx_List] := Length[DeleteDuplicates[Flatten[cmplx]]];
numFacets[cmplx_List] := Length[cmplx];
autOrder[cmplx_List] := PureComplexAutomorphismGroupOrder[cmplx];
facetAutOrder[cmplx_List] := PureComplexFacetAutomorphismGroupOrder[cmplx];
numVertexLabelings[cmplx_List] := numVert[cmplx]! / autOrder[cmplx];
numFacetLabelingsFormula[cmplx_List] := numFacets[cmplx]! / facetAutOrder[cmplx];
normalizePairs[pairs_List] := Module[{tot = Total[pairs[[All, 2]]]},
  ({#[[1]], N[#[[2]] / tot]} &) /@ pairs];
classDistFromClasses[classes_List] := Module[{cts = Counts[classes], n = Length[classes]},
  Table[{i, N[Lookup[cts, i, 0] / n]}, {i, 1, numClasses}]];
weightedClassDist[classes_List, weights_List] := Module[{tot = Total[weights]},
  Table[{i, N[Total[Pick[weights, classes, i]] / tot]}, {i, 1, numClasses}]];

(* ===== Class representatives ===== *)
allFacetLabeledForReps = GenerateAllFacetLabeledPureSimplicialComplexes[pq];
unlabeledPureComplexes = ChooseNonIsomorphicSimplicialComplexes[allFacetLabeledForReps];
unlabeledPureComplexes = ReverseSortBy[unlabeledPureComplexes, numVertexLabelings];
numClasses = Length[unlabeledPureComplexes];
classIndex[complex_List] := First @ FirstPosition[
  IsomorphicSimplicialComplexQ[#, complex] & /@ unlabeledPureComplexes, True];
If[(classIndex /@ unlabeledPureComplexes) =!= Range[numClasses],
  Print["  ERROR: class index sanity check failed"]; Abort[]];
Print["  classes: ", numClasses];

(* ===== Theory distributions ===== *)
vertexTheoryDist = normalizePairs[
  Table[{i, numVertexLabelings[unlabeledPureComplexes[[i]]]}, {i, 1, numClasses}]];
facetTheoryFormulaDist = normalizePairs[
  Table[{i, numFacetLabelingsFormula[unlabeledPureComplexes[[i]]]}, {i, 1, numClasses}]];
unlabeledTheoryDist = Table[{i, N[1 / numClasses]}, {i, 1, numClasses}];

classTable = Prepend[
  Table[With[{c = unlabeledPureComplexes[[i]]},
    {i, c, numVert[c], numFacets[c], autOrder[c], facetAutOrder[c], numVertexLabelings[c],
      numFacetLabelingsFormula[c], N[vertexTheoryDist[[i, 2]]], N[facetTheoryFormulaDist[[i, 2]]],
      N[unlabeledTheoryDist[[i, 2]]]}], {i, 1, numClasses}],
  {"classIndex", "representative", "numVertices", "numFacets", "vertexAutOrder", "facetAutOrder",
    "numVertexLabelings", "numFacetLabelingsFormula", "vertexTheoryProbability",
    "facetTheoryFormulaProbability", "unlabeledTheoryProbability"}];

(* ===== Vertex-labeled sample, reweighted distributions ===== *)
(* Draw on this kernel, before any subkernel exists: ECGrav's sampler uses
   subkernels when they are running, and theirs are not seeded, so the same
   seed would give a different sample each run. Classification (no randomness)
   then runs in parallel. *)
CloseKernels[];
t0 = AbsoluteTime[];
vertexSample = RandomVertexLabeledPureSimplicialComplex[pq, sampleSize];
LaunchKernels[];
combLoadECGravOnKernels[];
DistributeDefinitions[classIndex, unlabeledPureComplexes];
vertexClasses = ParallelMap[classIndex, vertexSample];
Print["  sampled and classified ", sampleSize, " in ", Round[AbsoluteTime[] - t0, 0.1], " s on ",
  Length[Kernels[]], " kernels"];

vertexEmpiricalDist = classDistFromClasses[vertexClasses];
unlabeledWeights = (autOrder[#] / numVert[#]!) & /@ vertexSample;
weightedUnlabeledDist = weightedClassDist[vertexClasses, unlabeledWeights];
facetWeightsFromVertex = (autOrder[#] * q! / (facetAutOrder[#] * numVert[#]!)) & /@ vertexSample;
weightedFacetDist = weightedClassDist[vertexClasses, facetWeightsFromVertex];
(* effective sample size of each panel: N for the unweighted draw, Kish ESS
   for the reweighted ones (tests/fig2_check.wl sets its tolerance from it) *)
kish[w_] := N[Total[w]^2 / Total[w^2]];
essByPanel = <|"vertex" -> N[sampleSize], "unlabeled" -> kish[unlabeledWeights],
  "facet" -> kish[facetWeightsFromVertex]|>;
Print["  ESS: ", essByPanel];

(* ===== Exact facet-labeled enumeration (diagnostic) ===== *)
exactFacetClasses = ParallelMap[classIndex, allFacetLabeledForReps];
exactFacetEnumeratedDist = classDistFromClasses[exactFacetClasses];
facetComparisonTable = Prepend[
  Table[{i, N[exactFacetEnumeratedDist[[i, 2]]], N[facetTheoryFormulaDist[[i, 2]]],
    N[exactFacetEnumeratedDist[[i, 2]] - facetTheoryFormulaDist[[i, 2]]]}, {i, 1, numClasses}],
  {"classIndex", "exactFacetEnumeratedProbability", "facetTheoryFormulaProbability",
    "differenceExactMinusFormula"}];
CloseKernels[];

l1[a_, b_] := Total[Abs[a[[All, 2]] - b[[All, 2]]]];
Print["  L1 vertex empirical vs theory   = ", l1[vertexEmpiricalDist, vertexTheoryDist]];
Print["  L1 unlabeled reweighted vs 1/", numClasses, " = ", l1[weightedUnlabeledDist, unlabeledTheoryDist]];
Print["  L1 facet reweighted vs formula  = ", l1[weightedFacetDist, facetTheoryFormulaDist]];
Print["  max |exact facet - formula|      = ", Max[Abs[facetComparisonTable[[2 ;;, 4]]]]];

exportWxfAtomic[dataFile, <|
    "p" -> pq[[1]], "q" -> q, "sampleSize" -> sampleSize, "seed" -> randomSeed,
    "numClasses" -> numClasses, "classTable" -> classTable,
    "vertexTheoryDist" -> vertexTheoryDist, "facetTheoryFormulaDist" -> facetTheoryFormulaDist,
    "unlabeledTheoryDist" -> unlabeledTheoryDist,
    "vertexEmpiricalDist" -> vertexEmpiricalDist, "weightedUnlabeledDist" -> weightedUnlabeledDist,
    "weightedFacetDist" -> weightedFacetDist, "exactFacetEnumeratedDist" -> exactFacetEnumeratedDist,
    "facetComparisonTable" -> facetComparisonTable, "vertexClasses" -> vertexClasses,
    "ess" -> essByPanel,
    "ecGravVersion" -> $CombECGravVersion, "createdAt" -> DateString[]|>,
  <|"seed" -> randomSeed, "seedRule" -> "SeedRandom[seed] before enumeration and sampling"|>];
Print["  wrote ", FileNameTake[dataFile]];

(* ===== The four paper panels (histograms_paper_figures.nb) ===== *)
barColor = RGBColor[0.984, 0.757, 0.369];
dotColor = RGBColor[0.122, 0.471, 0.706];
figOpts = Sequence[
  Frame -> True, FrameStyle -> Directive[Black, AbsoluteThickness[1]],
  FrameLabel -> {{"Frequency", None}, {"unlabeled 3-pure complex number (1-" <>
    ToString[numClasses] <> ")", None}},
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 11, Black],
  ImageSize -> {360, 270}, PlotRange -> All, ImageMargins -> 5];
paperBarPlot[dist_List, ttl_String] := BarChart[dist[[All, 2]], ChartStyle -> barColor,
  ChartLabels -> None, PlotLabel -> Style[ttl, FontFamily -> "Times", FontSize -> 12, Bold], figOpts];
paperBarVsTheoryPlot[dist_List, theoryDist_List, ttl_String] := Show[
  BarChart[dist[[All, 2]], ChartStyle -> barColor, ChartLabels -> None, figOpts],
  ListPlot[theoryDist, PlotStyle -> Directive[dotColor, AbsolutePointSize[7]],
    PlotMarkers -> {Graphics[{dotColor, Disk[]}], 0.05}],
  PlotLabel -> Style[ttl, FontFamily -> "Times", FontSize -> 12, Bold], PlotRange -> All];

fig1Unweighted = paperBarPlot[vertexEmpiricalDist, "Unweighted"];
fig2VertexLabeled = paperBarVsTheoryPlot[vertexEmpiricalDist, vertexTheoryDist, "Vertex-labeled"];
fig3FacetLabeled = paperBarVsTheoryPlot[weightedFacetDist, facetTheoryFormulaDist, "Facet-labeled"];
fig4Unlabeled = paperBarVsTheoryPlot[weightedUnlabeledDist, unlabeledTheoryDist, "Unlabeled"];
fig2x2 = GraphicsGrid[{{fig1Unweighted, fig2VertexLabeled}, {fig3FacetLabeled, fig4Unlabeled}},
  Spacings -> {0.3, 0.3}, ImageSize -> 760];

If[!DirectoryQ[figDir], CreateDirectory[figDir]];
Export[FileNameJoin[{figDir, baseName <> "_fig_unweighted.pdf"}], fig1Unweighted];
Export[FileNameJoin[{figDir, baseName <> "_fig_vertex_labeled.pdf"}], fig2VertexLabeled];
Export[FileNameJoin[{figDir, baseName <> "_fig_facet_labeled.pdf"}], fig3FacetLabeled];
Export[FileNameJoin[{figDir, baseName <> "_fig_unlabeled.pdf"}], fig4Unlabeled];
Export[FileNameJoin[{figDir, baseName <> "_fig2_combined.png"}], fig2x2, ImageResolution -> 144];
Export[combinedPdf, fig2x2];
Print["  wrote figures/fig2/", baseName, "_fig2_combined.{pdf,png} and 4 panel PDFs"];
Print["Done."];
