(* Standalone Figure 3 (numV) renderer for visual sanity check.
   Mirrors the notebook's makePanel / makeFigure logic. *)

qVal = 10;
pList = {2, 3, 4};
sampleSize = 10000;
outputDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];

colorVertex    = RGBColor[0.984, 0.757, 0.369];
colorFacet     = RGBColor[0.122, 0.471, 0.706];
colorUnlabeled = RGBColor[0.890, 0.290, 0.200];
seriesColors = {colorVertex, colorFacet, colorUnlabeled};
seriesNames  = {"vertex-labeled", "facet-labeled", "unlabeled"};

frameOpts = Sequence[
  Frame -> True,
  FrameStyle -> Directive[Black, AbsoluteThickness[1]],
  LabelStyle -> Directive[FontFamily -> "Times", FontSize -> 11, Black],
  ImageSize -> {360, 270},
  PlotRange -> All,
  ImageMargins -> 5];

loadSamples[p_] := Module[{path, raw, headers, body, cols, parseCol},
  path = FileNameJoin[{outputDir,
    "p" <> ToString[p] <> "q" <> ToString[qVal] <>
    "_n" <> ToString[sampleSize] <> "_samples.csv"}];
  raw = Import[path, "CSV"];
  headers = First[raw];
  body = Rest[raw];
  cols = Transpose[body];
  parseCol[col_] := Map[Function[x, Which[
    x === "", Missing[],
    StringQ[x], N[ToExpression[x]],
    True, x]], col];
  AssociationThread[headers -> (parseCol /@ cols)]];

sampleData = AssociationMap[loadSamples, pList];

weightedDist[vals_, weights_] := Module[{paired, agg, tot},
  paired = MapThread[List, {vals, weights}];
  agg = GroupBy[paired, First -> Last, Total];
  tot = Total[Values[agg]];
  SortBy[KeyValueMap[{#1, #2/tot} &, agg], First]];

makePanel[p_, col_, xLabel_] := Module[
  {s = sampleData[p], vals, wV, wF, wU, dV, dF, dU, allX, mat},
  vals = s[col]; wV = s["wVertex"]; wF = s["wFacet"]; wU = s["wUnlabeled"];
  dV = weightedDist[vals, wV];
  dF = weightedDist[vals, wF];
  dU = weightedDist[vals, wU];
  allX = Sort[DeleteDuplicates[
    Join[dV[[All, 1]], dF[[All, 1]], dU[[All, 1]]]]];
  mat = Table[
    Lookup[Association @@ (Rule @@@ d), x, 0.],
    {x, allX}, {d, {dV, dF, dU}}];
  BarChart[mat,
    ChartLayout -> "Grouped",
    ChartStyle -> seriesColors,
    ChartLabels -> {allX, None},
    ChartLegends -> Placed[seriesNames, Top],
    FrameLabel -> {{"Probability", None}, {xLabel, None}},
    PlotLabel -> Style["p = " <> ToString[p],
      FontFamily -> "Times", FontSize -> 12, Bold],
    frameOpts]];

panels = makePanel[#, "numV", "Number of vertices"] & /@ pList;
fig = GraphicsGrid[List /@ panels,
  Spacings -> {0.3, 0.3},
  ImageSize -> {380, 290 * Length[pList]}];

Export[FileNameJoin[{outputDir, "fig3_numVertices_TEST.pdf"}], fig];
Export[FileNameJoin[{outputDir, "fig3_numVertices_TEST.png"}], fig,
  ImageResolution -> 120];
Print["wrote fig3_numVertices_TEST.pdf and .png"];
