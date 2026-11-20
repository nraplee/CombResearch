(* render_truth_overlay.wl
   Truth/MH overlay renderer. Overlays exact-truth bars (from p{p}q{q}_truth.wxf)
   against MH chain bars (from p{p}q{q}_mh_{target}.wxf) for the
   reachableCells list below. No IS overlay; q=10 comparison panels stay in
   src/render_sampler_progress.wl.

   Inputs (from data/):
     p{p}q{q}_truth.wxf            — exact iso-class enumeration + 12-stat per class
     p{p}q{q}_mh_{target}.wxf      — MH chain stats rows (optional per cell × target)

   Outputs:
     figures/manuscript_panels/truthSX{Stat}[_conn]_p{p}q{q}_{target}.pdf
     figures/stacked_previews/truth_{stackedStem}_{target}.{pdf,png}
     figures/combined/combined_truth_overlay.pdf

   For each (stat, p, q, target) where truth WXF exists:
     truth bar = marginalize pi{Target} onto values of stat across
                 the iso classes that have a numeric value for stat
     MH bar    = empirical Counts[chainVals] / Length[chainVals]
   For filterSpec == "connected", restrict to connected==1 on both
   sides and report conditional probabilities. *)

(* ===== Paths ===== *)
scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];
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
  path = FileNameJoin[{dataDir,
    "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth.wxf"}];
  If[!FileExistsQ[path], truthCache[key] = $Failed; Return[$Failed]];
  truthCache[key] = Import[path, "WXF"]];

mhCache = <||>;
loadMH[p_, q_, target_] := Module[{key = {p, q, target}, path},
  If[KeyExistsQ[mhCache, key], Return[mhCache[key]]];
  path = FileNameJoin[{dataDir,
    "p" <> ToString[p] <> "q" <> ToString[q] <>
    "_mh_" <> target <> ".wxf"}];
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
Print["scriptDir         = ", scriptDir];
Print["dataDir           = ", dataDir];
Print["reachableCells    = ", reachableCells];

(* Optional cell restriction (for smoke test) *)
parseEnvCells[s_String] := Module[{pairs},
  pairs = StringSplit[StringTrim[s], ";"];
  pairs = StringSplit[#, ","] & /@ pairs;
  ToExpression /@ # & /@ pairs];
cellRestrict = If[StringQ[Environment["COMB_TRUTH_CELLS"]] &&
    StringLength[Environment["COMB_TRUTH_CELLS"]] > 0,
  parseEnvCells[Environment["COMB_TRUTH_CELLS"]],
  All];
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
