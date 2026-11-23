(* pipeline/60_figures.wl
   The figures stage (Phase 4 row 7): every manuscript and diagnostic figure,
   one job per process. run.wl figures runs each job with COMB_FIG_JOB set.
   Run by hand with the job as a plain word:

     wolframscript -file pipeline\60_figures.wl q10_stats
     wolframscript -file pipeline\60_figures.wl fig2          (COMB_FIG2_N, COMB_FIG2_SEED)

   Jobs (the old script each one was; that script is now a shim that sets
   the job and Gets this file):
     fig2              Figure 2 at q=3 (src/render_fig2.wl) ->
                       data/p3q3_n{N}_fig2.wxf, figures/fig2/
     truth_overlay     truth vs MH panels at the 9 truth cells
                       (src/render_truth_overlay.wl; COMB_TRUTH_CELLS) ->
                       figures/{manuscript_panels,stacked_previews,combined}/
     3way              IS / MH / truth grid at (3,5), (4,5) (src/render_3way.wl)
                       -> figures/is_vs_mh/q5_is_mh_truth_3way.{png,pdf}
     q10_is_vs_mh      IS vs MH grid at q=10 (src/render_q10_is_vs_mh.wl) ->
                       figures/is_vs_mh/q10_is_vs_mh_grid.{png,pdf}, q10_p4_focus.png
     q10_warm_vs_prod  warm-start vs production MH at q=10
                       (src/render_q10_warm_vs_prod.wl) ->
                       figures/is_vs_mh/q10_warm_vs_prod.{png,pdf}
     sampler_progress  MH vs enumeration and IS (src/render_sampler_progress.wl)
                       -> figures/sampler_diagnostics/sampler_mh_progress.{pdf,png}
     uniformity        MH per-iso-class uniformity at (2,4)
                       (src/render_uniformity_check.wl) ->
                       figures/sampler_diagnostics/sampler_mh_uniformity.{pdf,png}
     ecgrav_compare    MH facet vs ECGrav RandomFacetLabeled (the negative
                       control) vs truth at (2,4) (src/render_ecgrav_compare.wl)
                       -> figures/sampler_diagnostics/sampler_ecgrav_compare.{pdf,png}
     q10_stats         Figures 3-15 at q=10 (src/render_all_figures.wl) ->
                       figures/{stacked_previews,manuscript_panels,combined}/

   Inputs come from the earlier stages' data files. q10_stats reads the
   pre-binned data/p{p}q10_is_stat_hists.wxf (pipeline/22_is_hists.wl), not
   the 2.8 GB merged stats. The histograms, L1 distances and truth marginals
   are the package's (Compare.wl); MH chains are PureComplexMHChain. Panels
   are drawn as before. *)

$pipelineDir = DirectoryName[$InputFileName];
$srcDir = FileNameJoin[{ParentDirectory[$pipelineDir], "src"}];
Get[FileNameJoin[{$srcDir, "comb_paths.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_names.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_io.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_config.wl"}]];
(* loads ECGrav first; loaded before any job is parsed, so ECGrav's and the
   package's names resolve to their contexts *)
Get[FileNameJoin[{$srcDir, "load_combresearch.wl"}]];

$figureJobs = {"fig2", "truth_overlay", "3way", "q10_is_vs_mh", "q10_warm_vs_prod",
  "sampler_progress", "uniformity", "ecgrav_compare", "q10_stats"};
figJobName = Which[
  StringQ[$CombFigureJob], $CombFigureJob,
  ListQ[$ScriptCommandLine] && Length[$ScriptCommandLine] > 1 &&
    MemberQ[$figureJobs, $ScriptCommandLine[[2]]], $ScriptCommandLine[[2]],
  True, combSetting["COMB_FIG_JOB", None]];
If[!MemberQ[$figureJobs, figJobName],
  Print["60_figures: name a job: ", StringRiffle[$figureJobs, ", "],
    " (plain word or COMB_FIG_JOB); got ", figJobName];
  Exit[2]];
Print["60_figures job = ", figJobName];

(* ======================================================================
   fig2: Figure 2 of the paper, p=3 q=3 (was src/render_fig2.wl; header below)
   ====================================================================== *)
figJob["fig2"] := Module[{},

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
];

(* ======================================================================
   truth_overlay: exact truth vs MH at the truth cells (was src/render_truth_overlay.wl)
   ====================================================================== *)
figJob["truth_overlay"] := Module[{},
(* ===== Paths ===== *)
dataDir             = $CombDataDir;
figuresDir          = $CombFiguresDir;
stackedPreviewsDir  = FileNameJoin[{figuresDir, "stacked_previews"}];
manuscriptPanelsDir = FileNameJoin[{figuresDir, "manuscript_panels"}];
combinedDir         = FileNameJoin[{figuresDir, "combined"}];
If[!DirectoryQ[stackedPreviewsDir],  CreateDirectory[stackedPreviewsDir]];
If[!DirectoryQ[manuscriptPanelsDir], CreateDirectory[manuscriptPanelsDir]];
If[!DirectoryQ[combinedDir],         CreateDirectory[combinedDir]];

(* ===== Reachable grid =====
   Includes the 9-cell truth grid. For cells without MH WXFs, the renderer
   renders truth-only panels and skips the MH layer gracefully. *)
reachableCells = {{2, 4}, {2, 5}, {2, 6}, {2, 7},
                  {3, 4}, {3, 5}, {3, 6},
                  {4, 4}, {4, 5}};
allTargets = {"unlabeled", "facet", "vertex"};

(* ===== Style (mirrors render_all_figures.wl:36-56) ===== *)
colorTruth = RGBColor[0.122, 0.471, 0.706];   (* blue, solid-ish *)
colorMH    = RGBColor[0.890, 0.290, 0.200];   (* red, translucent *)
truthDirective = Directive[colorTruth, Opacity[0.85],
  EdgeForm[Directive[colorTruth, AbsoluteThickness[0.6]]]];
mhDirective    = Directive[colorMH, Opacity[0.55],
  EdgeForm[Directive[colorMH, AbsoluteThickness[0.4]]]];

frameOpts = Sequence[
  Frame -> True,
  FrameStyle -> Directive[Black, AbsoluteThickness[1]],
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 11, Black],
  ImageSize -> {360, 270},
  PlotRange -> All,
  ImageMargins -> 5];

panelLabel[p_, q_] := Style[
  "p = " <> ToString[p] <> ", q = " <> ToString[q],
  FontFamily -> "Times", FontSize -> 12, Bold];

mkLegend[hasTruth_, hasMH_] := SwatchLegend[
  Pick[{Directive[colorTruth, Opacity[0.85]],
        Directive[colorMH,    Opacity[0.55]]},
       {hasTruth, hasMH}],
  Pick[{"truth (exact)", "MH chain"}, {hasTruth, hasMH}],
  LegendMarkerSize -> 14,
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 10, Black]];

emptyPanel[p_, q_, msg_] := Graphics[
  Text[Style[msg <> " (p=" <> ToString[p] <>
    ", q=" <> ToString[q] <> ")",
    FontFamily -> "Times", FontSize -> 11, Gray]],
  frameOpts];

(* ===== Truth-WXF cache to avoid re-import per (stat × target) ===== *)
truthCache = <||>;
loadTruth[p_, q_] := Module[{key = {p, q}, path},
  If[KeyExistsQ[truthCache, key], Return[truthCache[key]]];
  path = FileNameJoin[{dataDir, combName["truth", p, q]}];
  If[!FileExistsQ[path], truthCache[key] = $Failed; Return[$Failed]];
  truthCache[key] = Import[path, "WXF"]];

mhCache = <||>;
loadMH[p_, q_, target_] := Module[{key = {p, q, target}, path},
  If[KeyExistsQ[mhCache, key], Return[mhCache[key]]];
  path = FileNameJoin[{dataDir, combName["mh", p, q, target]}];
  If[!FileExistsQ[path], mhCache[key] = $Failed; Return[$Failed]];
  mhCache[key] = Import[path, "WXF"]];

(* ===== Per-panel data extraction =====
   Returns Association: <|"truthVals", "truthMass", "mhVals", "label"|>
   where label = "u(N)" describing kept-row counts (for diagnostic only).
   $Failed if no data of either kind. *)
extractPanelData[p_, q_, statName_String, target_String, filterSpec_] :=
  Module[{truth, mh, complexes, mass, statRaw, connRaw,
          mask, truthVals, truthMass, mhVals, mhRows, mhConn,
          mhStatCol, mhConnCol, headers},
  truth = loadTruth[p, q];
  mh    = loadMH[p, q, target];

  (* ----- Truth side ----- *)
  If[truth =!= $Failed,
    complexes = truth["complexes"];
    mass = truth[Switch[target,
      "vertex",    "piVertex",
      "facet",     "piFacet",
      "unlabeled", "piUnlabeled",
      _, Print["unknown target: ", target]; Abort[]]];
    statRaw = (#["stats"][statName]) & /@ complexes;
    connRaw = (#["stats"]["connected"]) & /@ complexes;
    (* Filter: drop iso classes with "" stat values; if filterSpec ==
       "connected", also drop unconnected. Renormalize mass over kept. *)
    mask = MapThread[
      Function[{s, c},
        NumericQ[s] && (filterSpec === None || c === 1)],
      {statRaw, connRaw}];
    truthVals = Pick[statRaw, mask];
    truthMass = Pick[mass, mask];
    If[Length[truthVals] > 0,
      truthMass = N[truthMass / Total[truthMass]],
      truthMass = {}],
   (* else *)
    truthVals = $Failed;
    truthMass = $Failed];

  (* ----- MH side ----- *)
  If[mh =!= $Failed,
    headers = mh["headers"];
    mhRows  = mh["rows"];
    mhStatCol = Position[headers, statName];
    If[mhStatCol === {},
      mhVals = $Failed,
      mhStatCol = mhStatCol[[1, 1]];
      mhConnCol = Position[headers, "connected"][[1, 1]];
      mhConn = mhRows[[All, mhConnCol]];
      mhVals = mhRows[[All, mhStatCol]];
      mask = MapThread[
        Function[{s, c},
          NumericQ[s] && (filterSpec === None || c === 1)],
        {mhVals, mhConn}];
      mhVals = Pick[mhVals, mask]],
   (* else *)
    mhVals = $Failed];

  <|"truthVals" -> truthVals, "truthMass" -> truthMass,
    "mhVals"    -> mhVals|>];

(* ===== Panel builders =====
   Each takes panel data (truthVals, truthMass, mhVals) and returns
   a Graphics. Uses Histogram[{WeightedData,...}, ..., "PDF"] for visual
   parallelism with render_all_figures.wl's IS overlay. *)

makePanelDiscrete[p_, q_, statName_, xLabel_, target_, filterSpec_] :=
  Module[{d, tv, tm, mv, hasT, hasM, allKeys, lo, hi, series, styles},
  d = extractPanelData[p, q, statName, target, filterSpec];
  tv = d["truthVals"]; tm = d["truthMass"]; mv = d["mhVals"];
  hasT = (tv =!= $Failed) && Length[tv] > 0;
  hasM = (mv =!= $Failed) && Length[mv] > 0;
  If[!hasT && !hasM, Return[emptyPanel[p, q, "no data"]]];
  allKeys = Union[
    If[hasT, tv, {}],
    If[hasM, mv, {}]];
  lo = Floor[Min[allKeys]]; hi = Ceiling[Max[allKeys]];
  If[hi <= lo, hi = lo + 1];
  series = {
    If[hasT, WeightedData[tv, tm], Nothing],
    If[hasM, WeightedData[mv, ConstantArray[1./Length[mv], Length[mv]]],
      Nothing]};
  styles = {
    If[hasT, truthDirective, Nothing],
    If[hasM, mhDirective,    Nothing]};
  Histogram[series, {lo - 0.5, hi + 0.5, 1}, "PDF",
    ChartStyle    -> styles,
    ChartLegends  -> Placed[mkLegend[hasT, hasM], Top],
    FrameLabel    -> {{"Probability", None}, {xLabel, None}},
    PlotLabel     -> panelLabel[p, q],
    frameOpts]];

makePanelLogBin[p_, q_, statName_, xLabel_, target_, filterSpec_] :=
  Module[{d, tv, tm, mv, hasT, hasM, lv, mvLog, allKeys, lo, hi,
          series, styles, ticks},
  d = extractPanelData[p, q, statName, target, filterSpec];
  tv = d["truthVals"]; tm = d["truthMass"]; mv = d["mhVals"];
  hasT = (tv =!= $Failed) && Length[tv] > 0;
  hasM = (mv =!= $Failed) && Length[mv] > 0;
  If[!hasT && !hasM, Return[emptyPanel[p, q, "no data"]]];
  lv    = If[hasT, Log10[N[tv]], {}];
  mvLog = If[hasM, Log10[N[mv]], {}];
  allKeys = Join[lv, mvLog];
  lo = Floor[Min[allKeys]]; hi = Ceiling[Max[allKeys]];
  If[hi <= lo, hi = lo + 1];
  ticks = Table[{k + 0.5,
    Style[Superscript[10, k], FontFamily -> "Times", FontSize -> 10]},
    {k, lo, hi - 1}];
  series = {
    If[hasT, WeightedData[lv, tm], Nothing],
    If[hasM, WeightedData[mvLog, ConstantArray[1./Length[mvLog], Length[mvLog]]],
      Nothing]};
  styles = {
    If[hasT, truthDirective, Nothing],
    If[hasM, mhDirective,    Nothing]};
  Histogram[series, {lo, hi, 1}, "PDF",
    ChartStyle    -> styles,
    ChartLegends  -> Placed[mkLegend[hasT, hasM], Top],
    FrameLabel    -> {{"Probability per decade", None}, {xLabel, None}},
    FrameTicks    -> {{Automatic, None}, {ticks, None}},
    PlotLabel     -> panelLabel[p, q],
    frameOpts]];

makePanelContinuous[p_, q_, statName_, xLabel_, target_, filterSpec_] :=
  Module[{d, tv, tm, mv, hasT, hasM, series, styles},
  d = extractPanelData[p, q, statName, target, filterSpec];
  tv = d["truthVals"]; tm = d["truthMass"]; mv = d["mhVals"];
  hasT = (tv =!= $Failed) && Length[tv] > 0;
  hasM = (mv =!= $Failed) && Length[mv] > 0;
  If[!hasT && !hasM, Return[emptyPanel[p, q, "no data"]]];
  series = {
    If[hasT, WeightedData[N[tv], tm], Nothing],
    If[hasM, WeightedData[N[mv], ConstantArray[1./Length[mv], Length[mv]]],
      Nothing]};
  styles = {
    If[hasT, truthDirective, Nothing],
    If[hasM, mhDirective,    Nothing]};
  Histogram[series, Automatic, "PDF",
    ChartStyle    -> styles,
    ChartLegends  -> Placed[mkLegend[hasT, hasM], Top],
    FrameLabel    -> {{"Density", None}, {xLabel, None}},
    PlotLabel     -> panelLabel[p, q],
    frameOpts]];

panelDispatch["discrete",    args__] := makePanelDiscrete[args];
panelDispatch["logdiscrete", args__] := makePanelLogBin[args];
panelDispatch["continuous",  args__] := makePanelContinuous[args];

(* ===== Manuscript panel name builder =====
   Convention: truthSX{Stat}[_conn]_p{p}q{q}_{target}.pdf *)
manuscriptName[manStem_, p_, q_, target_, filterSpec_] :=
  "truthSX" <> manStem <>
  If[filterSpec === "connected", "_conn", ""] <>
  "_p" <> ToString[p] <> "q" <> ToString[q] <>
  "_" <> target;

(* ===== Figure list (adapted from render_all_figures.wl:211-224) =====
   Format: {stackedStem, statColumn, xLabel, panelType, pSubset, filterSpec, manStem}
   Automatic covers p in {2, 3, 4}. fig11/fig14 are restricted to p >= 3. *)
figs = {
  {"fig03_numVertices",      "numV",             "Number of vertices",                  "discrete",    Automatic, None,        "NumVertices"},
  {"fig04_autOrder",         "aut",              "|\[CapitalGamma](X)|",                "logdiscrete", Automatic, None,        "AutGorder"},
  {"fig05_autFOrder",        "autF",             "|\[CapitalGamma]_F(X)|",              "logdiscrete", Automatic, None,        "facetAutGorder"},
  {"fig06_autConnected",     "aut",              "|\[CapitalGamma](X)|, connected",     "logdiscrete", Automatic, "connected", "AutGorder"},
  {"fig07_autFConnected",    "autF",             "|\[CapitalGamma]_F(X)|, connected",   "logdiscrete", Automatic, "connected", "facetAutGorder"},
  {"fig08_num1VConnComps",   "num1VConnComps",   "Number of 1-vertex conn. components", "discrete",    Automatic, None,        "num1VConnectedComponents"},
  {"fig09_num2VConnComps",   "num2VConnComps",   "Number of 2-vertex conn. components", "discrete",    Automatic, None,        "num2VConnectedComponents"},
  {"fig10_largestCompRatio", "largestCompRatio", "Largest-component vertex ratio",      "continuous",  Automatic, None,        "ratioOflargestCompVsVertexCount"},
  {"fig11_num2PathConnComps","num2PathConnComps","Number of 2-path conn. components",   "discrete",    {3, 4},    None,        "num2PConnectedComponents"},
  {"fig13_Betti1",           "Betti1",           "\[Beta]_1",                           "discrete",    Automatic, None,        "Betti1"},
  {"fig14_Betti2",           "Betti2",           "\[Beta]_2",                           "discrete",    {3, 4},    None,        "Betti2"}};

(* ===== Cell selector ===== *)
qsForP[p_] := Cases[reachableCells, {p, q_} :> q];
cellsForFig[pSubset_] := Module[{ps},
  ps = If[pSubset === Automatic, {2, 3, 4}, pSubset];
  Flatten[Table[{p, q}, {p, ps}, {q, qsForP[p]}], 1]];

(* ===== Render driver ===== *)
Print["dataDir           = ", dataDir];
Print["reachableCells    = ", reachableCells];

(* Optional cell restriction (for smoke test) *)
cellRestrict = combSetting["COMB_TRUTH_CELLS", All, "cells"];
Print["cellRestrict      = ", cellRestrict];

allCombinedPages = {};
panelCount = 0;

Do[
  Module[{stackedStem, statName, xLabel, panelType, pSubset, filterSpec,
          manStem, cells, panel, mname, panelPath, panels, panelGrid,
          stackedBase},
    {stackedStem, statName, xLabel, panelType, pSubset, filterSpec, manStem} = f;
    cells = cellsForFig[pSubset];
    If[cellRestrict =!= All,
      cells = Select[cells, MemberQ[cellRestrict, #] &]];
    If[cells === {}, Continue[]];

    Print["building ", stackedStem, " / target=", target,
      "  cells=", cells];

    panels = Table[
      With[{p = cell[[1]], q = cell[[2]]},
        panel = panelDispatch[panelType, p, q, statName, xLabel,
          target, filterSpec];
        mname = manuscriptName[manStem, p, q, target, filterSpec];
        panelPath = FileNameJoin[{manuscriptPanelsDir, mname <> ".pdf"}];
        Export[panelPath, panel];
        panelCount += 1;
        panel],
      {cell, cells}];

    panelGrid = GraphicsGrid[List /@ panels,
      Spacings -> {0.3, 0.3},
      ImageSize -> {380, 290 * Length[panels]}];

    stackedBase = "truth_" <> stackedStem <> "_" <> target;
    Export[FileNameJoin[{stackedPreviewsDir, stackedBase <> ".pdf"}], panelGrid];
    Export[FileNameJoin[{stackedPreviewsDir, stackedBase <> ".png"}], panelGrid,
      ImageResolution -> 110];
    AppendTo[allCombinedPages, panelGrid]],
  {target, allTargets},
  {f, figs}];

(* ===== Combined multi-page PDF ===== *)
Module[{combinedPath = FileNameJoin[{combinedDir, "combined_truth_overlay.pdf"}]},
  Export[combinedPath, allCombinedPages];
  Print["wrote ", FileNameTake[combinedPath], " (", Length[allCombinedPages], " pages)"]];

Print["-----------------------------------------"];
Print["wrote ", panelCount, " individual manuscript panels"];
Print["wrote ", Length[figs] * Length[allTargets], " stacked previews (.pdf + .png)"];
Print["done."];
];

(* ======================================================================
   3way: IS, MH and truth at (3,5) and (4,5) (was src/render_3way.wl)
   ====================================================================== *)
figJob["3way"] := Module[{},
dataDir = $CombDataDir;
figDir  = FileNameJoin[{$CombFiguresDir, "is_vs_mh"}];
If[!DirectoryQ[figDir], CreateDirectory[figDir]];

truthFile[p_, q_] := combFile["truth", p, q];
mhFile[p_, q_, t_] := combFile["mh", p, q, t];
isFile[p_, q_, t_] := combFile["isHist", p, q, t];

(* numV marginals (Compare.wl): exact truth, MH sample fractions, L1 *)
marginalizeTruth[truth_, t_] := PureComplexTruthMarginal[truth, t];
binMh[mh_] := SampleHistogram[mh["rows"][[All, 1]]];
l1[a_, b_] := HistogramL1Distance[a, b];

(* ===== Manuscript style (matches the q10_stats job) ===== *)
colorIS    = RGBColor[0.122, 0.471, 0.706];   (* blue, like "facet" *)
colorMH    = RGBColor[0.890, 0.290, 0.200];   (* red, like "unlabeled" *)
colorTruth = Black;

frameOpts = Sequence[
  Frame -> True,
  FrameStyle -> Directive[Black, AbsoluteThickness[1]],
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 11, Black],
  ImageSize -> {380, 280},
  PlotRange -> All,
  ImageMargins -> 5,
  Background -> White];

panelLabel[p_, q_, t_, l1IsT_, l1MhT_, ess_] := Column[{
  Style["p = " <> ToString[p] <> ", q = " <> ToString[q] <>
        ", target = " <> t,
    FontFamily -> "Times", FontSize -> 12, Bold],
  Style[Row[{
    "L1(IS,T)=", NumberForm[l1IsT, {4, 3}],
    "   L1(MH,T)=", NumberForm[l1MhT, {4, 3}],
    "   IS ESS=", NumberForm[ess, 4]}],
    FontFamily -> "Times", FontSize -> 9, Black]},
  Center, 0.2];

translucentLegend = SwatchLegend[
  {Directive[colorIS, Opacity[0.55],
     EdgeForm[Directive[colorIS, AbsoluteThickness[0.4]]]],
   Directive[colorMH, Opacity[0.55],
     EdgeForm[Directive[colorMH, AbsoluteThickness[0.4]]]],
   Directive[Black, PointSize[Medium]]},
  {"IS reweighted", "MH chain", "truth"},
  LegendMarkerSize -> 14,
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 10, Black]];

(* Build a Histogram with two WeightedData "series" from precomputed
   per-bin fractions by treating each bin's fraction as the weight of
   one fake sample at that bin center. With bin breaks {lo-0.5, hi+0.5,
   1} and "PDF" normalization, the resulting bar heights equal the
   fraction values exactly, and adjacent bars touch. *)
panel[p_, q_, t_] := Module[
  {is, mh, truth, isBars, mhBars, tBars, keys, isV, mhV, tV,
   l1IsT, l1MhT, ess, lo, hi, truthPts},
  is    = Import[isFile[p, q, t], "WXF"];
  mh    = Import[mhFile[p, q, t], "WXF"];
  truth = Import[truthFile[p, q], "WXF"];
  isBars = is["fracHist"];
  mhBars = binMh[mh];
  tBars  = marginalizeTruth[truth, t];

  keys = Sort @ Union[Keys[isBars], Keys[mhBars], Keys[tBars]];
  isV  = Lookup[isBars, #, 0.] & /@ keys;
  mhV  = Lookup[mhBars, #, 0.] & /@ keys;
  tV   = N @ Lookup[tBars, #, 0.] & /@ keys;

  l1IsT = l1[isBars, tBars];
  l1MhT = l1[mhBars, tBars];
  ess   = is["ESS"];

  lo = First[keys]; hi = Last[keys];
  truthPts = Pick[Transpose[{keys, tV}], # > 0 & /@ tV];

  (* Legend via Legended, not ChartLegends -> Placed[..., Top]: in 15.0.1
     the placed chart legend stretches each panel to ~2800 px wide, and
     the 144-dpi PNG export then fails (Rasterize::bigraster). *)
  Legended[Show[
    Histogram[
      {WeightedData[keys, isV], WeightedData[keys, mhV]},
      {lo - 0.5, hi + 0.5, 1},
      "PDF",
      ChartStyle -> {
        Directive[colorIS, Opacity[0.55],
          EdgeForm[Directive[colorIS, AbsoluteThickness[0.4]]]],
        Directive[colorMH, Opacity[0.55],
          EdgeForm[Directive[colorMH, AbsoluteThickness[0.4]]]]},
      FrameLabel -> {{"fraction", None}, {"numV", None}},
      PlotLabel -> panelLabel[p, q, t, l1IsT, l1MhT, ess],
      frameOpts],
    Graphics[{Black, AbsolutePointSize[4], Point[truthPts]}]],
    Placed[translucentLegend, Top]]];

cells = {{3, 5}, {4, 5}};
targets = {"vertex", "unlabeled", "facet"};

Print["Rendering 2x3 3-way grid..."];
panels = Table[panel[cell[[1]], cell[[2]], t],
  {cell, cells}, {t, targets}];
grid = Grid[panels, Spacings -> {0.5, 0.5},
  Frame -> None, Background -> White];

(* Fail loudly: an Export that returns $Failed leaves the old file. *)
exportOrDie[name_, opts___] :=
  If[Export[FileNameJoin[{figDir, name}], grid, opts] === $Failed,
    Print["ERROR: export failed: ", name]; Exit[1],
    Print["wrote figures/is_vs_mh/", name]];

exportOrDie["q5_is_mh_truth_3way.png", ImageResolution -> 144];
exportOrDie["q5_is_mh_truth_3way.pdf"];

Print["Done."];
];

(* ======================================================================
   q10_is_vs_mh: IS vs MH at q=10 (was src/render_q10_is_vs_mh.wl)
   ====================================================================== *)
figJob["q10_is_vs_mh"] := Module[{},
dataDir = $CombDataDir;
figDir  = FileNameJoin[{$CombFiguresDir, "is_vs_mh"}];
If[!DirectoryQ[figDir], CreateDirectory[figDir]];

isFile[p_, t_] := combFile["isHist", p, 10, t];
mhFile[p_, t_] := combFile["mh", p, 10, t];

binMh[mh_Association] := SampleHistogram[mh["rows"][[All, 1]]];   (* Compare.wl *)

(* ===== Manuscript style ===== *)
colorIS = RGBColor[0.122, 0.471, 0.706];
colorMH = RGBColor[0.890, 0.290, 0.200];

frameOpts = Sequence[
  Frame -> True,
  FrameStyle -> Directive[Black, AbsoluteThickness[1]],
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 11, Black],
  ImageSize -> {380, 280},
  PlotRange -> All,
  ImageMargins -> 5,
  Background -> White];

translucentLegend = SwatchLegend[
  {Directive[colorIS, Opacity[0.55],
     EdgeForm[Directive[colorIS, AbsoluteThickness[0.4]]]],
   Directive[colorMH, Opacity[0.55],
     EdgeForm[Directive[colorMH, AbsoluteThickness[0.4]]]]},
  {"IS reweighted", "MH chain"},
  LegendMarkerSize -> 14,
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 10, Black]];

panel[p_, target_] := Module[
  {is, mh, isBars, mhBars, keys, isV, mhV, l1val, ess, niter, acc, lo, hi},
  is = Import[isFile[p, target], "WXF"];
  mh = Import[mhFile[p, target], "WXF"];
  isBars = is["fracHist"];
  mhBars = binMh[mh];
  keys = Sort @ Union[Keys[isBars], Keys[mhBars]];
  isV  = Lookup[isBars, #, 0.] & /@ keys;
  mhV  = Lookup[mhBars, #, 0.] & /@ keys;
  l1val = Total[Abs[isV - mhV]];
  ess   = is["ESS"];
  niter = mh["numIter"];
  acc   = mh["acceptRate"];
  lo = First[keys]; hi = Last[keys];

  Histogram[
    {WeightedData[keys, isV], WeightedData[keys, mhV]},
    {lo - 0.5, hi + 0.5, 1},
    "PDF",
    ChartStyle -> {
      Directive[colorIS, Opacity[0.55],
        EdgeForm[Directive[colorIS, AbsoluteThickness[0.4]]]],
      Directive[colorMH, Opacity[0.55],
        EdgeForm[Directive[colorMH, AbsoluteThickness[0.4]]]]},
    ChartLegends -> Placed[translucentLegend, Top],
    FrameLabel -> {{"fraction", None}, {"numV", None}},
    PlotLabel -> Column[{
      Style["p = " <> ToString[p] <> ", q = 10, target = " <> target,
        FontFamily -> "Times", FontSize -> 12, Bold],
      Style[Row[{
        "L1(IS,MH)=", NumberForm[l1val, {4, 3}],
        "   IS ESS=", NumberForm[ess, 3],
        "   MH n=", niter,
        "   acc=", NumberForm[acc, {3, 2}]}],
        FontFamily -> "Times", FontSize -> 9, Black]},
      Center, 0.2],
    frameOpts]];

ps = {2, 3, 4};
targets = {"vertex", "unlabeled", "facet"};

Print["Rendering 3x3 grid..."];
panels = Table[panel[p, t], {p, ps}, {t, targets}];
grid = Grid[panels, Spacings -> {0.5, 0.5},
  Frame -> None, Background -> White];

Export[FileNameJoin[{figDir, "q10_is_vs_mh_grid.png"}], grid,
  ImageResolution -> 144];
Print["wrote figures/is_vs_mh/q10_is_vs_mh_grid.png"];

Export[FileNameJoin[{figDir, "q10_is_vs_mh_grid.pdf"}], grid];
Print["wrote figures/is_vs_mh/q10_is_vs_mh_grid.pdf"];

(* Also render a focused 1x2 panel: (4,10) unlabeled and facet, the
   most-dramatic disagreement cells, for the writeup. *)
focus = Grid[{{panel[4, "unlabeled"], panel[4, "facet"]}},
  Spacings -> 0.5, Frame -> None, Background -> White];
Export[FileNameJoin[{figDir, "q10_p4_focus.png"}], focus,
  ImageResolution -> 144];
Print["wrote figures/is_vs_mh/q10_p4_focus.png"];

Print["Done."];
];

(* ======================================================================
   q10_warm_vs_prod: warm-start vs production MH at q=10 (was src/render_q10_warm_vs_prod.wl)
   ====================================================================== *)
figJob["q10_warm_vs_prod"] := Module[{},
dataDir = $CombDataDir;
figDir  = FileNameJoin[{$CombFiguresDir, "is_vs_mh"}];
If[!DirectoryQ[figDir], CreateDirectory[figDir]];

cells = {{3, 10, "unlabeled", 14}, {3, 10, "facet", 14},
         {4, 10, "unlabeled", 18}, {4, 10, "facet", 18}};

isFile[p_, q_, t_]     := combFile["isHist", p, q, t];
mhFile[p_, q_, t_]     := combFile["mh", p, q, t];
warmFile[p_, q_, t_, n_] := combFile["mh", p, q, t, combMHWarmTag[67890, n]];

(* numV marginals (Compare.wl) *)
binMh[mh_] := SampleHistogram[mh["rows"][[All, 1]]];
l1[a_, b_] := HistogramL1Distance[a, b];

(* ===== Manuscript style ===== *)
colorProd = RGBColor[0.890, 0.290, 0.200];   (* red *)
colorWarm = RGBColor[0.984, 0.757, 0.369];   (* warm gold *)

frameOpts = Sequence[
  Frame -> True,
  FrameStyle -> Directive[Black, AbsoluteThickness[1]],
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 11, Black],
  ImageSize -> {420, 300},
  PlotRange -> All,
  ImageMargins -> 5,
  Background -> White];

translucentLegend = SwatchLegend[
  {Directive[colorProd, Opacity[0.55],
     EdgeForm[Directive[colorProd, AbsoluteThickness[0.4]]]],
   Directive[colorWarm, Opacity[0.55],
     EdgeForm[Directive[colorWarm, AbsoluteThickness[0.4]]]],
   Directive[Black, PointSize[Medium]]},
  {"MH prod (seed12345)", "MH warm (seed67890 warm-init)", "IS"},
  LegendMarkerSize -> 14,
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 10, Black]];

panel[p_, q_, t_, nW_] := Module[
  {is, prod, warm, isBars, prodBars, warmBars,
   keys, isV, pV, wV, l1PW, l1IsP, l1IsW, lo, hi, isPts},
  is   = Import[isFile[p, q, t], "WXF"];
  prod = Import[mhFile[p, q, t], "WXF"];
  warm = Import[warmFile[p, q, t, nW], "WXF"];
  isBars   = is["fracHist"];
  prodBars = binMh[prod];
  warmBars = binMh[warm];

  keys = Sort @ Union[Keys[isBars], Keys[prodBars], Keys[warmBars]];
  isV  = Lookup[isBars,   #, 0.] & /@ keys;
  pV   = Lookup[prodBars, #, 0.] & /@ keys;
  wV   = Lookup[warmBars, #, 0.] & /@ keys;

  l1IsP = l1[isBars, prodBars];
  l1IsW = l1[isBars, warmBars];
  l1PW  = l1[prodBars, warmBars];

  lo = First[keys]; hi = Last[keys];
  isPts = Pick[Transpose[{keys, isV}], # > 0 & /@ isV];

  Show[
    Histogram[
      {WeightedData[keys, pV], WeightedData[keys, wV]},
      {lo - 0.5, hi + 0.5, 1},
      "PDF",
      ChartStyle -> {
        Directive[colorProd, Opacity[0.55],
          EdgeForm[Directive[colorProd, AbsoluteThickness[0.4]]]],
        Directive[colorWarm, Opacity[0.55],
          EdgeForm[Directive[colorWarm, AbsoluteThickness[0.4]]]]},
      ChartLegends -> Placed[translucentLegend, Top],
      FrameLabel -> {{"fraction", None}, {"numV", None}},
      PlotLabel -> Column[{
        Style["p = " <> ToString[p] <> ", q = " <> ToString[q] <>
              ", target = " <> t <> ", warm@numV=" <> ToString[nW],
          FontFamily -> "Times", FontSize -> 12, Bold],
        Style[Row[{
          "L1(prod,warm)=", NumberForm[l1PW, {4, 3}],
          "   L1(IS,prod)=", NumberForm[l1IsP, {4, 3}],
          "   L1(IS,warm)=", NumberForm[l1IsW, {4, 3}]}],
          FontFamily -> "Times", FontSize -> 9, Black]},
        Center, 0.2],
      frameOpts],
    Graphics[{Black, AbsolutePointSize[4], Point[isPts]}]]];

Print["Rendering 2x2 warm-vs-prod grid..."];
panels = Partition[panel @@@ cells, 2];
grid = Grid[panels, Spacings -> {0.5, 0.5},
  Frame -> None, Background -> White];

Export[FileNameJoin[{figDir, "q10_warm_vs_prod.png"}], grid,
  ImageResolution -> 144];
Print["wrote figures/is_vs_mh/q10_warm_vs_prod.png"];
Export[FileNameJoin[{figDir, "q10_warm_vs_prod.pdf"}], grid];
Print["wrote figures/is_vs_mh/q10_warm_vs_prod.pdf"];
Print["Done."];
];

(* ======================================================================
   sampler_progress: MH progress figure (was src/render_sampler_progress.wl)
   ====================================================================== *)
figJob["sampler_progress"] := Module[{},
(* ===== Style (matches existing figures) ===== *)
fontFam = "Times";
fontSz = 10;
panelSize = {360, 270};
truthColor = RGBColor[0.122, 0.471, 0.706]; (* blue, used for "truth" *)
mhColor    = RGBColor[0.890, 0.290, 0.200]; (* red, used for MH *)
isColor    = RGBColor[0.984, 0.757, 0.369]; (* yellow, used for IS reweighted *)

panelStyle[plot_, title_] := Show[plot,
  PlotLabel -> Style[title, FontFamily -> fontFam, FontSize -> fontSz + 1],
  BaseStyle -> {FontFamily -> fontFam, FontSize -> fontSz},
  ImageSize -> panelSize];

numActive[facets_List] := Length[DeleteDuplicates[Flatten[facets]]];

(* ===== Helper: normalized counts -> {bin, frac} pairs aligned to a key list ===== *)
alignedFracs[counts_Association, keys_List] := Module[{total},
  total = Total[Values[counts]];
  N[(Lookup[counts, #, 0] / total) & /@ keys]];

(* ===== Panel A: p=2 q=4 ===== *)
Print["[A] p=2 q=4 enumeration + MH ..."];
allLabA = GenerateAllFacetLabeledPureSimplicialComplexes[{2, 4}];
isoA = ChooseNonIsomorphicSimplicialComplexes[allLabA];
truthCountsA = Counts[Length[DeleteDuplicates[Flatten[#]]] & /@ isoA];
resA = PureComplexMHChain[2, 4, "unlabeled", 30000, "burnIn" -> 3000, "verbose" -> False];
mhCountsA = Counts[numActive /@ resA["trace"]];
keysA = Range[Min[Keys[truthCountsA]], Max[Keys[truthCountsA]]];
panelA = panelStyle[
  BarChart[Transpose[{alignedFracs[truthCountsA, keysA], alignedFracs[mhCountsA, keysA]}],
    ChartLabels -> {Placed[keysA, Below], None},
    ChartLegends -> Placed[{"truth (enumeration)", "MH chain (30k)"}, Top],
    ChartStyle -> {truthColor, mhColor},
    Frame -> True, FrameLabel -> {"numV", "fraction"},
    PlotRange -> {0, Automatic}],
  "p = 2, q = 4  (11 iso classes, fully enumerable)"];

(* ===== Panel B: p=3 q=4 ===== *)
Print["[B] p=3 q=4 enumeration + MH ..."];
allLabB = GenerateAllFacetLabeledPureSimplicialComplexes[{3, 4}];
isoB = ChooseNonIsomorphicSimplicialComplexes[allLabB];
truthCountsB = Counts[Length[DeleteDuplicates[Flatten[#]]] & /@ isoB];
resB = PureComplexMHChain[3, 4, "unlabeled", 50000, "burnIn" -> 5000, "verbose" -> False];
mhCountsB = Counts[numActive /@ resB["trace"]];
keysB = Range[Min[Keys[truthCountsB]], Max[Keys[truthCountsB]]];
panelB = panelStyle[
  BarChart[Transpose[{alignedFracs[truthCountsB, keysB], alignedFracs[mhCountsB, keysB]}],
    ChartLabels -> {Placed[keysB, Below], None},
    ChartLegends -> Placed[{"truth (enumeration)", "MH chain (50k)"}, Top],
    ChartStyle -> {truthColor, mhColor},
    Frame -> True, FrameLabel -> {"numV", "fraction"},
    PlotRange -> {0, Automatic}],
  "p = 3, q = 4  (66 iso classes, fully enumerable)"];

(* ===== Panel C: p=4 q=10 IS vs MH =====
   The first 500k batch, not the 12M merged file: same qualitative
   comparison, loads in seconds. Read from the batch's stats WXF (the same
   rows as the legacy p4q10_n500000_samples.csv, which this read before
   Phase 4 row 7). wU = aut/numV! recomputed from the aut column, as before. *)
Print["[C] p=4 q=10 MH + IS reweighted (500k batch) ..."];
isWxf = Import[combFile["isStats", combISStem[4, 10, 500000]], "WXF"];
isCol = AssociationThread[isWxf["headers"] -> Range[Length[isWxf["headers"]]]];
isRows = isWxf["rows"];
Print["  loaded ", Length[isRows], " rows"];
isNumVs = isRows[[All, isCol["numV"]]];
isAuts  = isRows[[All, isCol["aut"]]];
isWU    = MapThread[#1 / #2! &, {isAuts, isNumVs}];
isCountsRaw = Merge[Thread[isNumVs -> isWU], Total];
isCountsTotal = Total[Values[isCountsRaw]];
isFracs = AssociationThread[Keys[isCountsRaw] -> N[Values[isCountsRaw] / isCountsTotal]];
Print["  IS hist computed: ", Length[isFracs], " bins"];
resC = PureComplexMHChain[4, 10, "unlabeled", 25000, "burnIn" -> 5000, "verbose" -> False];
mhCountsC = Counts[numActive /@ resC["trace"]];
keysC = Range[
  Min[Min[Keys[isFracs]], Min[Keys[mhCountsC]]],
  Max[Max[Keys[isFracs]], Max[Keys[mhCountsC]]]];
panelC = panelStyle[
  BarChart[Transpose[{
      N[Lookup[isFracs, #, 0] & /@ keysC],
      alignedFracs[mhCountsC, keysC]}],
    ChartLabels -> {Placed[keysC, Below], None},
    ChartLegends -> Placed[{"IS reweighted (500k, ESS~4)", "MH chain (25k)"}, Top],
    ChartStyle -> {isColor, mhColor},
    Frame -> True, FrameLabel -> {"numV", "fraction"},
    PlotRange -> {0, Automatic}],
  "p = 4, q = 10  (no enumeration possible: IS vs MH)"];

(* ===== Compose ===== *)
Print["composing ..."];
fig = Grid[{{panelA, panelB, panelC}}, Spacings -> {2, 2}];

If[!DirectoryQ[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics"}]],
  CreateDirectory[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics"}]]];
Export[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics", "sampler_mh_progress.pdf"}], fig];
Export[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics", "sampler_mh_progress.png"}], fig,
  ImageResolution -> 150];
Print["wrote figures/sampler_diagnostics/sampler_mh_progress.{pdf,png}"];
];

(* ======================================================================
   uniformity: MH per-iso-class uniformity at (2,4) (was src/render_uniformity_check.wl)
   ====================================================================== *)
figJob["uniformity"] := Module[{},
(* ===== Enumerate iso classes at p=2 q=4 ===== *)
Print["enumerating p=2 q=4 ..."];
allLab = GenerateAllFacetLabeledPureSimplicialComplexes[{2, 4}];
isoClasses = ChooseNonIsomorphicSimplicialComplexes[allLab];
nIso = Length[isoClasses];
isoNumVs  = Length[DeleteDuplicates[Flatten[#]]] & /@ isoClasses;
isoAuts   = PureComplexAutomorphismGroupOrder /@ isoClasses;
isoAutFs  = PureComplexFacetAutomorphismGroupOrder /@ isoClasses;
Print["  ", nIso, " iso classes"];
Print["  numV per iso  : ", isoNumVs];
Print["  |Aut| per iso : ", isoAuts];
Print["  |Aut_F| per iso: ", isoAutFs];

(* Sort iso classes by (numV, |Aut|) for readable plot ordering. *)
sortOrder = Ordering[Transpose[{isoNumVs, isoAuts}]];
isoClasses = isoClasses[[sortOrder]];
isoNumVs   = isoNumVs[[sortOrder]];
isoAuts    = isoAuts[[sortOrder]];
isoAutFs   = isoAutFs[[sortOrder]];

(* Group iso indices by numV for fast matching *)
indicesByNumV = GroupBy[Range[nIso], isoNumVs[[#]] &];

(* Map an MH state to its iso class index. Filter candidates by numV first
   so we only do iso checks against ~3 candidates instead of all 11. *)
matchIsoClass[X_List] := Module[{m, candidates, hit},
  m = Length[DeleteDuplicates[Flatten[X]]];
  candidates = Lookup[indicesByNumV, m, {}];
  hit = SelectFirst[candidates,
    IsomorphicSimplicialComplexQ[X, isoClasses[[#]]] &, Missing[]];
  hit];

(* ===== Run unlabeled MH and match ===== *)
Print["[A] target=unlabeled, 30k+3k burn ..."];
resU = PureComplexMHChain[2, 4, "unlabeled", 30000, "burnIn" -> 3000, "verbose" -> False];
matchU = matchIsoClass /@ resU["trace"];
nMissing = Count[matchU, _Missing];
If[nMissing > 0, Print["  WARNING: ", nMissing, " states unmatched (bug!)"]];
empU = Counts[matchU];
empUFracs = N[(Lookup[empU, #, 0] & /@ Range[nIso]) / Length[matchU]];
truthU = ConstantArray[N[1/nIso], nIso];

(* ===== Run facet MH and match ===== *)
Print["[B] target=facet, 30k+3k burn ..."];
resF = PureComplexMHChain[2, 4, "facet", 30000, "burnIn" -> 3000, "verbose" -> False];
matchF = matchIsoClass /@ resF["trace"];
nMissingF = Count[matchF, _Missing];
If[nMissingF > 0, Print["  WARNING: ", nMissingF, " states unmatched (bug!)"]];
empF = Counts[matchF];
empFFracs = N[(Lookup[empF, #, 0] & /@ Range[nIso]) / Length[matchF]];
fLabelCounts = N[4! / isoAutFs];
truthF = fLabelCounts / Total[fLabelCounts];

(* ===== Diagnostic prints ===== *)
Print["unlabeled empirical vs truth (per iso class):"];
Do[Print["  iso ", i, " (numV=", isoNumVs[[i]], "): emp=",
  NumberForm[empUFracs[[i]], {5, 4}],
  "  truth=", NumberForm[truthU[[i]], {5, 4}]],
  {i, nIso}];
Print["facet empirical vs truth (per iso class):"];
Do[Print["  iso ", i, " (numV=", isoNumVs[[i]],
  ", |Aut_F|=", isoAutFs[[i]],
  "): emp=", NumberForm[empFFracs[[i]], {5, 4}],
  "  truth=", NumberForm[truthF[[i]], {5, 4}]],
  {i, nIso}];

(* ===== Plot ===== *)
fontFam = "Times"; fontSz = 10;
panelSize = {500, 320};
truthColor = RGBColor[0.122, 0.471, 0.706];
mhColor    = RGBColor[0.890, 0.290, 0.200];

panelStyle[plot_, title_] := Show[plot,
  PlotLabel -> Style[title, FontFamily -> fontFam, FontSize -> fontSz + 1],
  BaseStyle -> {FontFamily -> fontFam, FontSize -> fontSz},
  ImageSize -> panelSize];

(* Annotate iso classes with numV for readability *)
labelsX = ("[" <> ToString[#] <> "]" &) /@ Range[nIso];

panelU = panelStyle[
  BarChart[Transpose[{truthU, empUFracs}],
    ChartLabels -> {Placed[labelsX, Below], None},
    ChartLegends -> Placed[{"truth (uniform = 1/11)", "MH unlabeled (30k)"}, Top],
    ChartStyle -> {truthColor, mhColor},
    Frame -> True, FrameLabel -> {"iso class index", "fraction of samples"},
    PlotRange -> {0, Automatic}],
  "p=2 q=4 — target=unlabeled (truth: uniform on 11 iso classes)"];

panelF = panelStyle[
  BarChart[Transpose[{truthF, empFFracs}],
    ChartLabels -> {Placed[labelsX, Below], None},
    ChartLegends -> Placed[{"truth ∝ q!/|Aut_F|", "MH facet (30k)"}, Top],
    ChartStyle -> {truthColor, mhColor},
    Frame -> True, FrameLabel -> {"iso class index", "fraction of samples"},
    PlotRange -> {0, Automatic}],
  "p=2 q=4 — target=facet (truth ∝ q!/|Aut_F|)"];

If[!DirectoryQ[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics"}]],
  CreateDirectory[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics"}]]];
fig = Grid[{{panelU}, {panelF}}, Spacings -> {0, 1}];
Export[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics", "sampler_mh_uniformity.pdf"}], fig];
Export[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics", "sampler_mh_uniformity.png"}], fig,
  ImageResolution -> 150];
Print["wrote figures/sampler_diagnostics/sampler_mh_uniformity.{pdf,png}"];
];

(* ======================================================================
   ecgrav_compare: MH facet vs ECGrav RandomFacetLabeled vs truth (was src/render_ecgrav_compare.wl)
   ====================================================================== *)
figJob["ecgrav_compare"] := Module[{},
Print["enumerating p=2 q=4 ..."];
isoClasses = ChooseNonIsomorphicSimplicialComplexes[
  GenerateAllFacetLabeledPureSimplicialComplexes[{2, 4}]];
nIso = Length[isoClasses];
isoNumVs = Length[DeleteDuplicates[Flatten[#]]] & /@ isoClasses;
isoAutFs = PureComplexFacetAutomorphismGroupOrder /@ isoClasses;

(* Sort by (numV, |Aut_F|) for readable plot ordering *)
sortOrder = Ordering[Transpose[{isoNumVs, isoAutFs}]];
isoClasses = isoClasses[[sortOrder]];
isoNumVs = isoNumVs[[sortOrder]];
isoAutFs = isoAutFs[[sortOrder]];
indicesByNumV = GroupBy[Range[nIso], isoNumVs[[#]] &];

matchIso[X_List] := Module[{m, cands},
  m = Length[DeleteDuplicates[Flatten[X]]];
  cands = Lookup[indicesByNumV, m, {}];
  SelectFirst[cands, IsomorphicSimplicialComplexQ[X, isoClasses[[#]]] &, Missing[]]];

(* === MH facet === *)
Print["MH facet 30k+3k burn ..."];
mhRes = PureComplexMHChain[2, 4, "facet", 30000, "burnIn" -> 3000, "verbose" -> False];
mhMatches = matchIso /@ mhRes["trace"];
mhCounts = Counts[mhMatches];
mhFracs = N[(Lookup[mhCounts, #, 0] & /@ Range[nIso]) / Length[mhMatches]];

(* === ECGrav RandomFacetLabeled === *)
Print["ECGrav RandomFacetLabeledPureSimplicialComplex 30k ..."];
SeedRandom[2024];
ecSamples = RandomFacetLabeledPureSimplicialComplex[{2, 4}, 30000];
ecMatches = matchIso /@ ecSamples;
nMissing = Count[ecMatches, _Missing];
If[nMissing > 0, Print["  WARNING: ", nMissing, " ECGrav samples unmatched"]];
ecCounts = Counts[ecMatches];
ecFracs = N[(Lookup[ecCounts, #, 0] & /@ Range[nIso]) / Length[ecMatches]];

(* === Truth === *)
truthRaw = N[4!/isoAutFs];
truthFracs = truthRaw / Total[truthRaw];

(* === Diagnostic prints === *)
Print["per-iso-class fractions (truth | MH facet | ECGrav):"];
Do[Print["  iso ", i, " (numV=", isoNumVs[[i]], ", |Aut_F|=", isoAutFs[[i]],
  "):  ", NumberForm[truthFracs[[i]], {5, 4}],
  "  ", NumberForm[mhFracs[[i]], {5, 4}],
  "  ", NumberForm[ecFracs[[i]], {5, 4}]],
  {i, nIso}];

(* L1 distance to truth *)
Print["L1 distance to truth:"];
Print["  MH facet  : ", N[Total[Abs[mhFracs - truthFracs]]]];
Print["  ECGrav    : ", N[Total[Abs[ecFracs - truthFracs]]]];

(* === Plot === *)
fontFam = "Times"; fontSz = 10;
truthColor = RGBColor[0.122, 0.471, 0.706];
mhColor = RGBColor[0.890, 0.290, 0.200];
ecColor = RGBColor[0.4, 0.7, 0.3];

labelsX = ("[" <> ToString[#] <> "]" &) /@ Range[nIso];

panel = Show[
  BarChart[Transpose[{truthFracs, mhFracs, ecFracs}],
    ChartLabels -> {Placed[labelsX, Below], None},
    ChartLegends -> Placed[
      {"truth (q!/|Aut_F|)", "MH facet (30k)", "ECGrav RandomFacetLabeled (30k)"},
      Top],
    ChartStyle -> {truthColor, mhColor, ecColor},
    Frame -> True, FrameLabel -> {"iso class index", "fraction of samples"},
    PlotRange -> {0, Automatic}],
  PlotLabel -> Style[
    "p=2 q=4: MH facet vs ECGrav RandomFacetLabeled vs truth",
    FontFamily -> fontFam, FontSize -> fontSz + 1],
  BaseStyle -> {FontFamily -> fontFam, FontSize -> fontSz},
  ImageSize -> {800, 400}];

If[!DirectoryQ[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics"}]],
  CreateDirectory[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics"}]]];
Export[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics", "sampler_ecgrav_compare.pdf"}], panel];
Export[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics", "sampler_ecgrav_compare.png"}], panel,
  ImageResolution -> 150];
Print["wrote figures/sampler_diagnostics/sampler_ecgrav_compare.{pdf,png}"];
];

(* ======================================================================
   q10_stats: Figures 3-15 at q=10 (was src/render_all_figures.wl)
   ====================================================================== *)
figJob["q10_stats"] := Module[{},
(* ===== paths ===== *)
dataDir             = $CombDataDir;
figuresDir          = $CombFiguresDir;
stackedPreviewsDir  = FileNameJoin[{figuresDir, "stacked_previews"}];
manuscriptPanelsDir = FileNameJoin[{figuresDir, "manuscript_panels"}];
combinedDir         = FileNameJoin[{figuresDir, "combined"}];

If[!DirectoryQ[stackedPreviewsDir],  CreateDirectory[stackedPreviewsDir]];
If[!DirectoryQ[manuscriptPanelsDir], CreateDirectory[manuscriptPanelsDir]];
If[!DirectoryQ[combinedDir],         CreateDirectory[combinedDir]];

Print["dataDir             = ", dataDir];
Print["figuresDir          = ", figuresDir];

(* ===== parameters ===== *)
qVal = 10;
pList = {2, 3, 4};
sampleTag  = "merged";   (* the hists are of the merged 12M samples per p *)

(* ===== style ===== *)
colorVertex    = RGBColor[0.984, 0.757, 0.369];
colorFacet     = RGBColor[0.122, 0.471, 0.706];
colorUnlabeled = RGBColor[0.890, 0.290, 0.200];
seriesColorsTrans = {
  Directive[colorVertex,    Opacity[0.55], EdgeForm[Directive[colorVertex,    AbsoluteThickness[0.4]]]],
  Directive[colorFacet,     Opacity[0.55], EdgeForm[Directive[colorFacet,     AbsoluteThickness[0.4]]]],
  Directive[colorUnlabeled, Opacity[0.55], EdgeForm[Directive[colorUnlabeled, AbsoluteThickness[0.4]]]]};
seriesNames = {"vertex-labeled", "facet-labeled", "unlabeled"};
seriesTargets = {"vertex", "facet", "unlabeled"};   (* same order as seriesNames *)
legendSwatches = {colorVertex, colorFacet, colorUnlabeled};

frameOpts = Sequence[
  Frame -> True,
  FrameStyle -> Directive[Black, AbsoluteThickness[1]],
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 11, Black],
  ImageSize -> {360, 270},
  PlotRange -> All,
  ImageMargins -> 5];

panelLabel[p_] := Style["p = " <> ToString[p],
  FontFamily -> "Times", FontSize -> 12, Bold];

(* ===== load =====
   data/p{p}q10_is_stat_hists.wxf (pipeline/22_is_hists.wl): per statistic,
   filter ("all", "connected") and target, exact value -> weighted fraction
   of the merged IS samples. Before Phase 4 row 7 this job read the merged
   stats themselves (2.8 GB) and binned them here; a Histogram of the
   distinct values weighted by their fractions has the same bars (to
   rounding), since every bin is a set of values. *)
Print["----- loading statistic histograms -----"];
sampleData = AssociationMap[Function[p, Module[{f = combFile["isStatHists", p, qVal]},
    If[!FileExistsQ[f],
      Print["  ERROR: no ", FileNameTake[f], " (run.wl is makes it)"]; Exit[1]];
    Print["  loading ", FileNameTake[f]];
    Import[f, "WXF"]]], pList];

(* ===== ESS sanity check at top ===== *)
Print["----- ESS sanity check -----"];
Do[
  Module[{s = sampleData[p], essV, essF, essU, n, fmt},
    n = s["n"]["all"];
    {essV, essF, essU} = Lookup[s["ESS"]["all"], {"vertex", "facet", "unlabeled"}];
    fmt[ess_] := ToString[Round[ess]] <> " / " <> ToString[n] <>
      " (" <> ToString[NumberForm[100. ess / n, {4, 3}]] <> "%)";
    Print["  p=", p, "  ESS_vertex=", fmt[essV]];
    Print["         ESS_facet =", fmt[essF]];
    Print["         ESS_unlab =", fmt[essU]];
    If[Min[essU, essF] < 100,
      Print["  *** WARNING: ESS below 100 — bar heights unreliable for p=", p, " ***"]]],
  {p, pList}];

(* ===== helpers ===== *)
(* {values, weights} per target (seriesTargets order) for one statistic and
   filter; {} when the statistic has no numeric value at this p *)
extractSeries[s_, col_, filterSpec_] := Module[
  {h = s["hists"][col][If[filterSpec === "connected", "connected", "all"]]},
  If[AnyTrue[seriesTargets, h[#] === <||> &], {},
    {N[Keys[h[#]]], Values[h[#]]} & /@ seriesTargets]];
allValues[series_] := Union @@ series[[All, 1]];

emptyPanel[p_, msg_] := Graphics[
  Text[Style[msg <> " (p=" <> ToString[p] <> ")",
    FontFamily -> "Times", FontSize -> 11, Gray]],
  frameOpts];

translucentLegend = SwatchLegend[
  Directive[#, Opacity[0.55]] & /@ legendSwatches,
  seriesNames,
  LegendMarkerSize -> 14,
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 10, Black]];

(* ===== panels ===== *)
(* All three panel functions use Histogram with three WeightedData series
   plotted on the same axes with translucent fill. *)

makePanelDiscrete[p_, col_, xLabel_, filterSpec_:None] := Module[
  {series, vals, lo, hi},
  series = extractSeries[sampleData[p], col, filterSpec];
  If[series === {}, Return[emptyPanel[p, "no data"]]];
  vals = allValues[series];
  lo = Floor[Min[vals]];
  hi = Ceiling[Max[vals]];
  If[hi <= lo, hi = lo + 1];
  Histogram[
    WeightedData @@@ series,
    {lo - 0.5, hi + 0.5, 1},
    "PDF",
    ChartStyle -> seriesColorsTrans,
    ChartLegends -> Placed[translucentLegend, Top],
    FrameLabel -> {{"Probability", None}, {xLabel, None}},
    PlotLabel -> panelLabel[p],
    frameOpts]];

makePanelLogBin[p_, col_, xLabel_, filterSpec_:None] := Module[
  {series, logVals, lo, hi, ticks},
  series = extractSeries[sampleData[p], col, filterSpec];
  If[series === {}, Return[emptyPanel[p, "no data"]]];
  series = {Log10[#[[1]]], #[[2]]} & /@ series;
  logVals = allValues[series];
  lo = Floor[Min[logVals]];
  hi = Ceiling[Max[logVals]];
  If[hi <= lo, hi = lo + 1];
  ticks = Table[{k + 0.5,
      Style[Superscript[10, k], FontFamily -> "Times", FontSize -> 10]},
    {k, lo, hi - 1}];
  Histogram[
    WeightedData @@@ series,
    {lo, hi, 1},
    "PDF",
    ChartStyle -> seriesColorsTrans,
    ChartLegends -> Placed[translucentLegend, Top],
    FrameLabel -> {{"Probability per decade", None},
      {xLabel, None}},
    FrameTicks -> {{Automatic, None}, {ticks, None}},
    PlotLabel -> panelLabel[p],
    frameOpts]];

(* Fixed bins of width 1/20 from the 1/20 below the smallest value to just
   past the largest. Automatic bins chosen on the distinct values would
   differ from those chosen on the raw samples; on the stored merged samples
   Automatic chose exactly these (1/10 to 21/20 for every p and target). *)
continuousBins[vals_] := {Floor[20 Min[vals]]/20, Floor[20 Max[vals]]/20 + 1/20, 1/20};

makePanelContinuous[p_, col_, xLabel_, filterSpec_:None] := Module[
  {series},
  series = extractSeries[sampleData[p], col, filterSpec];
  If[series === {}, Return[emptyPanel[p, "no data"]]];
  Histogram[
    WeightedData @@@ series,
    continuousBins[allValues[series]], "PDF",
    ChartStyle -> seriesColorsTrans,
    ChartLegends -> Placed[translucentLegend, Top],
    FrameLabel -> {{"Density", None}, {xLabel, None}},
    PlotLabel -> panelLabel[p],
    frameOpts]];

panelDispatch["discrete", args__]    := makePanelDiscrete[args];
panelDispatch["logdiscrete", args__] := makePanelLogBin[args];
panelDispatch["continuous", args__]  := makePanelContinuous[args];

(* ===== manuscript panel name builder ===== *)
(* Convention: p{p}q10[conn]SX{Stat}_{sampleTag}.pdf *)
manuscriptName[stem_, p_, filterSpec_] :=
  "p" <> ToString[p] <> "q10" <>
  If[filterSpec === "connected", "conn", ""] <>
  "SX" <> stem <> "_" <> sampleTag;

(* ===== figure list =====
   Each row: {stackedFileStem, csvColumn, xAxisLabel, panelType, pSubset, filterSpec, manuscriptStem} *)
figs = {
  {"fig03_numVertices",      "numV",             "Number of vertices",                         "discrete",    Automatic, None,        "NumVertices"},
  {"fig04_autOrder",         "aut",              "|\[CapitalGamma](X)|",                       "logdiscrete", Automatic, None,        "AutGorder"},
  {"fig05_autFOrder",        "autF",             "|\[CapitalGamma]_F(X)|",                     "logdiscrete", Automatic, None,        "facetAutGorder"},
  {"fig06_autConnected",     "aut",              "|\[CapitalGamma](X)|, connected",            "logdiscrete", Automatic, "connected", "AutGorder"},
  {"fig07_autFConnected",    "autF",             "|\[CapitalGamma]_F(X)|, connected",          "logdiscrete", Automatic, "connected", "facetAutGorder"},
  {"fig08_num1VConnComps",   "num1VConnComps",   "Number of 1-vertex conn. components",        "discrete",    Automatic, None,        "num1VConnectedComponents"},
  {"fig09_num2VConnComps",   "num2VConnComps",   "Number of 2-vertex conn. components",        "discrete",    Automatic, None,        "num2VConnectedComponents"},
  {"fig10_largestCompRatio", "largestCompRatio", "Largest-component vertex ratio",             "continuous",  Automatic, None,        "ratioOflargestCompVsVertexCount"},
  {"fig11_num2PathConnComps","num2PathConnComps","Number of 2-path conn. components",          "discrete",    {3, 4},    None,        "num2PConnectedComponents"},
  {"fig12_num3PathConnComps","num3PathConnComps","Number of 3-path conn. components",          "discrete",    {4},       None,        "num3PConnectedComponents"},
  {"fig13_Betti1",           "Betti1",           "\[Beta]_1",                                  "discrete",    Automatic, None,        "Betti1"},
  {"fig14_Betti2",           "Betti2",           "\[Beta]_2",                                  "discrete",    {3, 4},    None,        "Betti2"},
  {"fig15_Betti3",           "Betti3",           "\[Beta]_3",                                  "discrete",    {4},       None,        "Betti3"}};

(* ===== render loop =====
   For each figure:
     - build per-p panels
     - export each per-p panel as individual PDF (manuscript_panels/)
     - build the stacked column grid; export as PDF + PNG (stacked_previews/)
     - accumulate the stacked grid into the combined-PDF page list *)

allCombinedPages = {};
panelCount = 0;

Print["----- rendering figures -----"];
Do[
  Module[{name, col, lbl, type, ps, filt, manStem, panels, panelGrid, panelPath},
    {name, col, lbl, type, ps, filt, manStem} = f;
    Print["building ", name, " ..."];

    panels = Table[
      Module[{panel, mname},
        panel = panelDispatch[type, p, col, lbl, filt];
        mname = manuscriptName[manStem, p, filt];
        panelPath = FileNameJoin[{manuscriptPanelsDir, mname <> ".pdf"}];
        Export[panelPath, panel];
        Print["  panel: ", mname, ".pdf"];
        panelCount += 1;
        panel],
      {p, If[ps === Automatic, pList, ps]}];

    panelGrid = GraphicsGrid[List /@ panels,
      Spacings -> {0.3, 0.3},
      ImageSize -> {380, 290 * Length[panels]}];

    Export[FileNameJoin[{stackedPreviewsDir, name <> ".pdf"}], panelGrid];
    Export[FileNameJoin[{stackedPreviewsDir, name <> ".png"}], panelGrid,
      ImageResolution -> 110];
    Print["  stacked: ", name, ".pdf / .png"];

    AppendTo[allCombinedPages, panelGrid]],
  {f, figs}];

(* ===== combined multi-page PDF ===== *)
Print["----- combined PDF -----"];
Module[{combinedPath = FileNameJoin[{combinedDir,
    "combined_all_figures_" <> sampleTag <> ".pdf"}]},
  Export[combinedPath, allCombinedPages];
  Print["wrote ", FileNameTake[combinedPath]]];

Print["-----------------------------------------"];
Print["wrote ", panelCount, " individual manuscript panels"];
Print["wrote ", Length[figs], " stacked preview pairs (.pdf + .png)"];
Print["wrote 1 combined multi-page PDF"];
Print["done."];
];

figJob[figJobName];
