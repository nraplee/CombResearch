(* render_q10_is_vs_mh.wl
   Render a 3x3 grid (rows = p in {2,3,4}, cols = target in
   {vertex, unlabeled, facet}) of overlay panels comparing the
   IS-reweighted numV histogram against the MH-sampled one at q=10.

   Writes:
     figures/is_vs_mh/q10_is_vs_mh_grid.png
     figures/is_vs_mh/q10_is_vs_mh_grid.pdf
*)

dataDir = "C:/CombResearch/data";
figDir  = "C:/CombResearch/figures/is_vs_mh";
If[!DirectoryQ[figDir], CreateDirectory[figDir]];

isFile[p_, t_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q10_is_" <> t <> "_numv_hist.wxf"}];
mhFile[p_, t_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q10_mh_" <> t <> ".wxf"}];

binMh[mh_Association] := Module[{vals},
  vals = Select[mh["rows"][[All, 1]], NumericQ];
  If[Length[vals] == 0, <||>,
    KeySort @ N[Counts[vals] / Length[vals]]]];

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
