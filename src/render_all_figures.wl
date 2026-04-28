(* render_all_figures.wl
   Renders Figures 3-15 from p{2,3,4}q10_merged_stats.wxf (in ../data/).
   Three panel modes — all rendered as TRANSLUCENT OVERLAID histograms
   (matching paper Figure 2 style), not grouped bars:
     "discrete"     — Histogram with bin width 1, integer x values
     "logdiscrete"  — Histogram of Log10[val], one bin per decade, 10^k tick labels
     "continuous"   — Histogram with Automatic bins
   Outputs:
     ../figures/stacked_previews/fig{03..15}_*.{pdf,png}   (one stacked column per fig)
     ../figures/manuscript_panels/p{p}q10[conn]SX{Stat}_merged.pdf (~30 panels)
     ../figures/combined_all_figures_merged.pdf            (multi-page combined)
   Prints per-p ESS at startup. *)

(* ===== paths ===== *)
projectRoot = ParentDirectory[
  If[ValueQ[$InputFileName] && $InputFileName =!= "",
    DirectoryName[$InputFileName], Directory[]]];
dataDir             = FileNameJoin[{projectRoot, "data"}];
figuresDir          = FileNameJoin[{projectRoot, "figures"}];
stackedPreviewsDir  = FileNameJoin[{figuresDir, "stacked_previews"}];
manuscriptPanelsDir = FileNameJoin[{figuresDir, "manuscript_panels"}];

If[!DirectoryQ[stackedPreviewsDir],  CreateDirectory[stackedPreviewsDir]];
If[!DirectoryQ[manuscriptPanelsDir], CreateDirectory[manuscriptPanelsDir]];

Print["projectRoot         = ", projectRoot];
Print["dataDir             = ", dataDir];
Print["figuresDir          = ", figuresDir];

(* ===== parameters ===== *)
qVal = 10;
pList = {2, 3, 4};
sampleSize = 12000000;  (* informational only — stem reads merged file directly *)
sampleTag  = "merged";

(* ===== style ===== *)
colorVertex    = RGBColor[0.984, 0.757, 0.369];
colorFacet     = RGBColor[0.122, 0.471, 0.706];
colorUnlabeled = RGBColor[0.890, 0.290, 0.200];
seriesColorsTrans = {
  Directive[colorVertex,    Opacity[0.55], EdgeForm[Directive[colorVertex,    AbsoluteThickness[0.4]]]],
  Directive[colorFacet,     Opacity[0.55], EdgeForm[Directive[colorFacet,     AbsoluteThickness[0.4]]]],
  Directive[colorUnlabeled, Opacity[0.55], EdgeForm[Directive[colorUnlabeled, AbsoluteThickness[0.4]]]]};
seriesNames = {"vertex-labeled", "facet-labeled", "unlabeled"};
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
   Prefers WXF (fast, typed). Falls back to legacy CSV if no WXF present. *)
stem[p_] := "p" <> ToString[p] <> "q" <> ToString[qVal] <> "_merged";

loadSamplesWXF[path_] := Module[{a, headers, rows},
  Print["  loading ", FileNameTake[path], " (WXF)"];
  a = Import[path, "WXF"];
  headers = Lookup[a, "headers"];
  rows    = Lookup[a, "rows"];
  AssociationThread[headers -> Transpose[rows]]];

loadSamplesCSV[path_] := Module[{raw, headers, body, cols, parseCol},
  Print["  loading ", FileNameTake[path], " (CSV, legacy)"];
  raw = Import[path, "CSV"];
  headers = First[raw];
  body = Rest[raw];
  cols = Transpose[body];
  parseCol[col_] := Map[Function[x, Which[
    x === "", Missing[],
    StringQ[x], N[ToExpression[x]],
    True, x]], col];
  AssociationThread[headers -> (parseCol /@ cols)]];

loadSamples[p_] := Module[{wxf, csv},
  wxf = FileNameJoin[{dataDir, stem[p] <> "_stats.wxf"}];
  csv = FileNameJoin[{dataDir, stem[p] <> "_samples.csv"}];
  Which[
    FileExistsQ[wxf], loadSamplesWXF[wxf],
    FileExistsQ[csv], loadSamplesCSV[csv],
    True, Print["  ERROR: no data for p=", p]; Abort[]]];

Print["----- loading samples -----"];
sampleData = AssociationMap[loadSamples, pList];

(* ===== ESS sanity check at top ===== *)
Print["----- ESS sanity check -----"];
Do[
  Module[{s = sampleData[p], wV, wF, wU, essV, essF, essU, n,
          fmt},
    wV = s["wVertex"]; wF = s["wFacet"]; wU = s["wUnlabeled"];
    n = Length[wV];
    essV = N[Total[wV]^2 / Total[wV^2]];
    essF = N[Total[wF]^2 / Total[wF^2]];
    essU = N[Total[wU]^2 / Total[wU^2]];
    fmt[ess_] := ToString[Round[ess]] <> " / " <> ToString[n] <>
      " (" <> ToString[NumberForm[100. ess / n, {4, 3}]] <> "%)";
    Print["  p=", p, "  ESS_vertex=", fmt[essV]];
    Print["         ESS_facet =", fmt[essF]];
    Print["         ESS_unlab =", fmt[essU]];
    If[Min[essU, essF] < 100,
      Print["  *** WARNING: ESS below 100 — bar heights unreliable for p=", p, " ***"]]],
  {p, pList}];

(* ===== helpers ===== *)
filterMask[s_, None]        := ConstantArray[True, Length[s["numV"]]];
filterMask[s_, "connected"] := (# == 1 &) /@ s["connected"];

extractSeries[s_, col_, filterSpec_] := Module[{mask, vals, wV, wF, wU, keep},
  mask = filterMask[s, filterSpec];
  vals = Pick[s[col], mask];
  wV   = Pick[s["wVertex"], mask];
  wF   = Pick[s["wFacet"], mask];
  wU   = Pick[s["wUnlabeled"], mask];
  keep = (! MissingQ[#]) & /@ vals;
  {Pick[vals, keep], Pick[wV, keep], Pick[wF, keep], Pick[wU, keep]}];

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
  {s = sampleData[p], vals, wV, wF, wU, lo, hi},
  {vals, wV, wF, wU} = extractSeries[s, col, filterSpec];
  If[Length[vals] == 0, Return[emptyPanel[p, "no data"]]];
  lo = Floor[Min[vals]];
  hi = Ceiling[Max[vals]];
  If[hi <= lo, hi = lo + 1];
  Histogram[
    {WeightedData[vals, wV],
     WeightedData[vals, wF],
     WeightedData[vals, wU]},
    {lo - 0.5, hi + 0.5, 1},
    "PDF",
    ChartStyle -> seriesColorsTrans,
    ChartLegends -> Placed[translucentLegend, Top],
    FrameLabel -> {{"Probability", None}, {xLabel, None}},
    PlotLabel -> panelLabel[p],
    frameOpts]];

makePanelLogBin[p_, col_, xLabel_, filterSpec_:None] := Module[
  {s = sampleData[p], vals, wV, wF, wU, logVals, lo, hi, ticks},
  {vals, wV, wF, wU} = extractSeries[s, col, filterSpec];
  If[Length[vals] == 0, Return[emptyPanel[p, "no data"]]];
  logVals = Log10[N[vals]];
  lo = Floor[Min[logVals]];
  hi = Ceiling[Max[logVals]];
  If[hi <= lo, hi = lo + 1];
  ticks = Table[{k + 0.5,
      Style[Superscript[10, k], FontFamily -> "Times", FontSize -> 10]},
    {k, lo, hi - 1}];
  Histogram[
    {WeightedData[logVals, wV],
     WeightedData[logVals, wF],
     WeightedData[logVals, wU]},
    {lo, hi, 1},
    "PDF",
    ChartStyle -> seriesColorsTrans,
    ChartLegends -> Placed[translucentLegend, Top],
    FrameLabel -> {{"Probability per decade", None},
      {xLabel, None}},
    FrameTicks -> {{Automatic, None}, {ticks, None}},
    PlotLabel -> panelLabel[p],
    frameOpts]];

makePanelContinuous[p_, col_, xLabel_, filterSpec_:None] := Module[
  {s = sampleData[p], vals, wV, wF, wU},
  {vals, wV, wF, wU} = extractSeries[s, col, filterSpec];
  If[Length[vals] == 0, Return[emptyPanel[p, "no data"]]];
  Histogram[
    {WeightedData[vals, wV],
     WeightedData[vals, wF],
     WeightedData[vals, wU]},
    Automatic, "PDF",
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
Module[{combinedPath = FileNameJoin[{figuresDir,
    "combined_all_figures_" <> sampleTag <> ".pdf"}]},
  Export[combinedPath, allCombinedPages];
  Print["wrote ", FileNameTake[combinedPath]]];

Print["-----------------------------------------"];
Print["wrote ", panelCount, " individual manuscript panels"];
Print["wrote ", Length[figs], " stacked preview pairs (.pdf + .png)"];
Print["wrote 1 combined multi-page PDF"];
Print["done."];
