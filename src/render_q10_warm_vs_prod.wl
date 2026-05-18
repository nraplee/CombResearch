(* render_q10_warm_vs_prod.wl
   2x2 grid (rows = p in {3,4}, cols = target in {unlabeled, facet})
   overlaying IS, MH_prod (seed 12345), and MH_warm (seed 67890,
   warm-start) numV histograms.

   Writes:
     figures/is_vs_mh/q10_warm_vs_prod.png
     figures/is_vs_mh/q10_warm_vs_prod.pdf
*)

dataDir = "C:/CombResearch/data";
figDir  = "C:/CombResearch/figures/is_vs_mh";
If[!DirectoryQ[figDir], CreateDirectory[figDir]];

cells = {{3, 10, "unlabeled", 14}, {3, 10, "facet", 14},
         {4, 10, "unlabeled", 18}, {4, 10, "facet", 18}};

isFile[p_, q_, t_]     := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <>
  "_is_" <> t <> "_numv_hist.wxf"}];
mhFile[p_, q_, t_]     := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_mh_" <> t <> ".wxf"}];
warmFile[p_, q_, t_, n_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <>
  "_mh_" <> t <> "_seed67890_warm" <> ToString[n] <> ".wxf"}];

binMh[mh_] := Module[{vals},
  vals = Select[mh["rows"][[All, 1]], NumericQ];
  If[Length[vals] == 0, <||>,
    KeySort @ N[Counts[vals] / Length[vals]]]];

l1[a_, b_] := Module[{keys, av, bv},
  keys = Sort @ Union[Keys[a], Keys[b]];
  av = Lookup[a, #, 0.] & /@ keys;
  bv = Lookup[b, #, 0.] & /@ keys;
  Total[Abs[av - bv]]];

halfW = 0.42;

panel[p_, q_, t_, nW_] := Module[
  {is, prod, warm, isBars, prodBars, warmBars,
   keys, isV, pV, wV, l1PW, l1IsP, l1IsW, title,
   prodRects, warmRects, isPts, yMax, xLo, xHi},
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

  title = Row[{
    "p=", p, ", target=", t, ", warm@numV=", nW,
    "  |  L1(prod,warm)=", NumberForm[l1PW, {4, 3}],
    "  L1(IS,prod)=", NumberForm[l1IsP, {4, 3}],
    "  L1(IS,warm)=", NumberForm[l1IsW, {4, 3}]}];

  prodRects = MapThread[Rectangle[{# - halfW, 0}, {# + halfW, #2}] &,
    {keys, pV}];
  warmRects = MapThread[Rectangle[{# - halfW, 0}, {# + halfW, #2}] &,
    {keys, wV}];
  isPts = Pick[Transpose[{keys, isV}], # > 0 & /@ isV];
  yMax = 1.08 * Max[isV, pV, wV];
  xLo  = First[keys] - 0.6;
  xHi  = Last[keys]  + 0.6;

  Graphics[{
    EdgeForm[None],
    Directive[Opacity[0.55], RGBColor[0.85, 0.40, 0.20]], prodRects,
    Directive[Opacity[0.55], RGBColor[0.20, 0.65, 0.30]], warmRects,
    Black, AbsolutePointSize[4], Point[isPts]},
    Frame -> True,
    FrameLabel -> {"numV", "fraction"},
    FrameTicks -> {
      {Automatic, None},
      {Transpose[{keys, ToString /@ keys}], None}},
    PlotLabel -> Style[title, 10, Black],
    PlotRange -> {{xLo, xHi}, {0, yMax}},
    AspectRatio -> 1/2,
    ImageSize -> 580,
    Background -> White]];

legendRow = Graphics[{
  Opacity[0.55], RGBColor[0.85, 0.40, 0.20],
  EdgeForm[None], Rectangle[{0, 0}, {1.4, 0.7}],
  Opacity[1], Black,
  Text[Style["MH prod (seed12345)", FontSize -> 12], {1.8, 0.35}, {-1, 0}],
  Opacity[0.55], RGBColor[0.20, 0.65, 0.30],
  EdgeForm[None], Rectangle[{8.4, 0}, {9.8, 0.7}],
  Opacity[1], Black,
  Text[Style["MH warm (seed67890 warm-init)", FontSize -> 12],
    {10.2, 0.35}, {-1, 0}],
  Black, AbsolutePointSize[5], Point[{19.0, 0.35}],
  Text[Style["IS", FontSize -> 12], {19.3, 0.35}, {-1, 0}]},
  PlotRange -> {{0, 21}, {-0.3, 1.0}},
  AspectRatio -> Automatic, ImageSize -> 620, Background -> White];

Print["Rendering 2x2 warm-vs-prod grid..."];
panels = Partition[panel @@@ cells, 2];
grid = Column[{
  legendRow,
  Grid[panels, Spacings -> {0.5, 0.5},
    Frame -> All, FrameStyle -> LightGray]},
  Alignment -> Center, Background -> White];

Export[FileNameJoin[{figDir, "q10_warm_vs_prod.png"}], grid,
  ImageResolution -> 144];
Print["wrote figures/is_vs_mh/q10_warm_vs_prod.png"];
Export[FileNameJoin[{figDir, "q10_warm_vs_prod.pdf"}], grid];
Print["wrote figures/is_vs_mh/q10_warm_vs_prod.pdf"];
Print["Done."];
