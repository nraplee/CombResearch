(* render_3way.wl
   2x3 grid of overlay panels: rows = cells {(3,5),(4,5)}, cols =
   targets {vertex, unlabeled, facet}. Each panel overlays IS, MH, and
   truth as grouped bars.

   Writes:
     figures/is_vs_mh/q5_is_mh_truth_3way.png
     figures/is_vs_mh/q5_is_mh_truth_3way.pdf
*)

dataDir = "C:/CombResearch/data";
figDir  = "C:/CombResearch/figures/is_vs_mh";
If[!DirectoryQ[figDir], CreateDirectory[figDir]];

truthFile[p_, q_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth.wxf"}];
mhFile[p_, q_, t_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_mh_" <> t <> ".wxf"}];
isFile[p_, q_, t_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <>
  "_is_" <> t <> "_numv_hist.wxf"}];

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

(* Half-width of each bin's bar rectangle (in numV units). 0.42 leaves
   a small gap between adjacent bins. *)
halfW = 0.42;

(* Manuscript style: white background, black frame, IS and MH as
   translucent overlapping rectangles (so where they agree the colors
   blend), truth as small filled black dots centered on the bins.
   Bars and dots share one coordinate system, so dots sit exactly at
   bar centers. *)
panel[p_, q_, t_] := Module[
  {is, mh, truth, isBars, mhBars, tBars, keys, isV, mhV, tV,
   l1IsT, l1MhT, ess, title, isRects, mhRects, truthPts,
   yMax, xLo, xHi},
  is    = Import[isFile[p, q, t], "WXF"];
  mh    = Import[mhFile[p, q, t], "WXF"];
  truth = Import[truthFile[p, q], "WXF"];
  isBars = is["fracHist"];
  mhBars = binMh[mh];
  tBars  = marginalizeTruth[truth, t];

  keys = Sort @ Union[Keys[isBars], Keys[mhBars], Keys[tBars]];
  isV  = Lookup[isBars, #, 0.] & /@ keys;
  mhV  = Lookup[mhBars, #, 0.] & /@ keys;
  tV   = N @ Lookup[tBars,  #, 0.] & /@ keys;

  l1IsT = l1[isBars, tBars];
  l1MhT = l1[mhBars, tBars];
  ess   = is["ESS"];

  title = Row[{
    "p=", p, ",q=", q, ", target=", t,
    "  |  L1(IS,T)=", NumberForm[l1IsT, {4, 3}],
    "  L1(MH,T)=", NumberForm[l1MhT, {4, 3}],
    "  IS ESS=", NumberForm[ess, 4]}];

  isRects = MapThread[Rectangle[{# - halfW, 0}, {# + halfW, #2}] &,
    {keys, isV}];
  mhRects = MapThread[Rectangle[{# - halfW, 0}, {# + halfW, #2}] &,
    {keys, mhV}];
  truthPts = Pick[Transpose[{keys, tV}], # > 0 & /@ tV];

  yMax = 1.08 * Max[isV, mhV, tV];
  xLo  = First[keys] - 0.6;
  xHi  = Last[keys]  + 0.6;

  Graphics[{
    EdgeForm[None],
    Directive[Opacity[0.55], RGBColor[0.20, 0.45, 0.85]], isRects,
    Directive[Opacity[0.55], RGBColor[0.95, 0.50, 0.10]], mhRects,
    Black, AbsolutePointSize[4], Point[truthPts]},
    Frame -> True,
    FrameLabel -> {"numV", "fraction"},
    FrameTicks -> {
      {Automatic, None},  (* y: left only *)
      {Transpose[{keys, ToString /@ keys}], None}},  (* x: bottom only *)
    PlotLabel -> Style[title, 10, Black],
    PlotRange -> {{xLo, xHi}, {0, yMax}},
    AspectRatio -> 1/2,
    ImageSize -> 560,
    Background -> White]];

cells = {{3, 5}, {4, 5}};
targets = {"vertex", "unlabeled", "facet"};

legendRow = Graphics[{
  (* IS swatch *)
  Opacity[0.55], RGBColor[0.20, 0.45, 0.85],
  EdgeForm[None], Rectangle[{0, 0}, {1.4, 0.7}],
  Opacity[1], Black,
  Text[Style["IS reweighted", FontSize -> 12], {1.8, 0.35}, {-1, 0}],
  (* MH swatch *)
  Opacity[0.55], RGBColor[0.95, 0.50, 0.10],
  EdgeForm[None], Rectangle[{5.8, 0}, {7.2, 0.7}],
  Opacity[1], Black,
  Text[Style["MH chain", FontSize -> 12], {7.6, 0.35}, {-1, 0}],
  (* truth dot *)
  Black, AbsolutePointSize[5], Point[{11.0, 0.35}],
  Text[Style["truth", FontSize -> 12], {11.3, 0.35}, {-1, 0}]},
  PlotRange -> {{0, 13}, {-0.3, 1.0}},
  AspectRatio -> Automatic,
  ImageSize -> 480, Background -> White];

Print["Rendering 2x3 3-way grid..."];
panels = Table[panel[cell[[1]], cell[[2]], t],
  {cell, cells}, {t, targets}];
grid = Column[{
  legendRow,
  Grid[panels, Spacings -> {0.5, 0.5},
    Frame -> All, FrameStyle -> LightGray]},
  Alignment -> Center, Background -> White];

Export[FileNameJoin[{figDir, "q5_is_mh_truth_3way.png"}], grid,
  ImageResolution -> 144];
Print["wrote figures/is_vs_mh/q5_is_mh_truth_3way.png"];

Export[FileNameJoin[{figDir, "q5_is_mh_truth_3way.pdf"}], grid];
Print["wrote figures/is_vs_mh/q5_is_mh_truth_3way.pdf"];

Print["Done."];
