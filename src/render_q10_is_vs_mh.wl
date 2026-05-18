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

halfW = 0.42;

panel[p_, target_] := Module[
  {is, mh, isBars, mhBars, keys, isV, mhV, l1val, ess, niter, acc,
   title, isRects, mhRects, yMax, xLo, xHi},
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
  title = Row[{
    "p=", p, ", target=", target,
    "  |  L1=", NumberForm[l1val, {4, 3}],
    "  IS ESS=", NumberForm[ess, 3],
    "  MH n=", niter,
    "  acc=", NumberForm[acc, {3, 2}]}];
  isRects = MapThread[Rectangle[{# - halfW, 0}, {# + halfW, #2}] &,
    {keys, isV}];
  mhRects = MapThread[Rectangle[{# - halfW, 0}, {# + halfW, #2}] &,
    {keys, mhV}];
  yMax = 1.08 * Max[isV, mhV];
  xLo  = First[keys] - 0.6;
  xHi  = Last[keys]  + 0.6;
  Graphics[{
    EdgeForm[None],
    Directive[Opacity[0.55], RGBColor[0.20, 0.45, 0.85]], isRects,
    Directive[Opacity[0.55], RGBColor[0.95, 0.50, 0.10]], mhRects},
    Frame -> True,
    FrameLabel -> {"numV", "fraction"},
    FrameTicks -> {
      {Automatic, None},
      {Transpose[{keys, ToString /@ keys}], None}},
    PlotLabel -> Style[title, 10, Black],
    PlotRange -> {{xLo, xHi}, {0, yMax}},
    AspectRatio -> 1/2,
    ImageSize -> 540,
    Background -> White]];

legendRow = Graphics[{
  Opacity[0.55], RGBColor[0.20, 0.45, 0.85],
  EdgeForm[None], Rectangle[{0, 0}, {1.4, 0.7}],
  Opacity[1], Black,
  Text[Style["IS reweighted", FontSize -> 12], {1.8, 0.35}, {-1, 0}],
  Opacity[0.55], RGBColor[0.95, 0.50, 0.10],
  EdgeForm[None], Rectangle[{5.8, 0}, {7.2, 0.7}],
  Opacity[1], Black,
  Text[Style["MH chain", FontSize -> 12], {7.6, 0.35}, {-1, 0}]},
  PlotRange -> {{0, 11}, {-0.3, 1.0}},
  AspectRatio -> Automatic, ImageSize -> 360, Background -> White];

ps = {2, 3, 4};
targets = {"vertex", "unlabeled", "facet"};

Print["Rendering 3x3 grid..."];
panels = Table[panel[p, t], {p, ps}, {t, targets}];
grid = Column[{
  legendRow,
  Grid[panels, Spacings -> {0.5, 0.5}, Frame -> All,
    FrameStyle -> LightGray]},
  Alignment -> Center, Background -> White];

Export[FileNameJoin[{figDir, "q10_is_vs_mh_grid.png"}], grid,
  ImageResolution -> 144];
Print["wrote figures/is_vs_mh/q10_is_vs_mh_grid.png"];

Export[FileNameJoin[{figDir, "q10_is_vs_mh_grid.pdf"}], grid];
Print["wrote figures/is_vs_mh/q10_is_vs_mh_grid.pdf"];

(* Also render a focused 1x2 panel: (4,10) unlabeled and facet, the
   most-dramatic disagreement cells, for the writeup. *)
focus = Column[{
  legendRow,
  Grid[{{panel[4, "unlabeled"], panel[4, "facet"]}},
    Spacings -> 0.5, Frame -> All, FrameStyle -> LightGray]},
  Alignment -> Center, Background -> White];
Export[FileNameJoin[{figDir, "q10_p4_focus.png"}], focus,
  ImageResolution -> 144];
Print["wrote figures/is_vs_mh/q10_p4_focus.png"];

Print["Done."];
