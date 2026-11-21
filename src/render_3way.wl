(* render_3way.wl
   2x3 grid of overlay panels: rows = cells {(3,5),(4,5)}, cols =
   targets {vertex, unlabeled, facet}. Each panel overlays IS, MH, and
   truth as grouped bars.

   Writes:
     figures/is_vs_mh/q5_is_mh_truth_3way.png
     figures/is_vs_mh/q5_is_mh_truth_3way.pdf
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "lib_names.wl"}]];
dataDir = $CombDataDir;
figDir  = FileNameJoin[{$CombFiguresDir, "is_vs_mh"}];
If[!DirectoryQ[figDir], CreateDirectory[figDir]];

truthFile[p_, q_] := combFile["truth", p, q];
mhFile[p_, q_, t_] := combFile["mh", p, q, t];
isFile[p_, q_, t_] := combFile["isHist", p, q, t];

piKey = <|"vertex" -> "piVertex", "facet" -> "piFacet",
          "unlabeled" -> "piUnlabeled"|>;

marginalizeTruth[truth_, t_] := Module[{pi, numVs},
  pi = truth[piKey[t]];
  numVs = #["stats"]["numV"] & /@ truth["complexes"];
  Total /@ GroupBy[Transpose[{numVs, pi}], First -> Last]];

binMh[mh_] := Module[{vals},
  vals = Select[mh["rows"][[All, 1]], NumericQ];
  If[Length[vals] == 0, <||>,
    KeySort @ N[Counts[vals] / Length[vals]]]];

l1[a_, b_] := Module[{keys, av, bv},
  keys = Sort @ Union[Keys[a], Keys[b]];
  av = Lookup[a, #, 0.] & /@ keys;
  bv = Lookup[b, #, 0.] & /@ keys;
  Total[Abs[av - bv]]];

(* ===== Manuscript style (matches src/render_all_figures.wl) ===== *)
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

  Show[
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
      PlotLabel -> panelLabel[p, q, t, l1IsT, l1MhT, ess],
      frameOpts],
    Graphics[{Black, AbsolutePointSize[4], Point[truthPts]}]]];

cells = {{3, 5}, {4, 5}};
targets = {"vertex", "unlabeled", "facet"};

Print["Rendering 2x3 3-way grid..."];
panels = Table[panel[cell[[1]], cell[[2]], t],
  {cell, cells}, {t, targets}];
grid = Grid[panels, Spacings -> {0.5, 0.5},
  Frame -> None, Background -> White];

Export[FileNameJoin[{figDir, "q5_is_mh_truth_3way.png"}], grid,
  ImageResolution -> 144];
Print["wrote figures/is_vs_mh/q5_is_mh_truth_3way.png"];

Export[FileNameJoin[{figDir, "q5_is_mh_truth_3way.pdf"}], grid];
Print["wrote figures/is_vs_mh/q5_is_mh_truth_3way.pdf"];

Print["Done."];
