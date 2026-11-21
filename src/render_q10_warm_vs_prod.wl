(* render_q10_warm_vs_prod.wl
   2x2 grid (rows = p in {3,4}, cols = target in {unlabeled, facet})
   overlaying IS, MH_prod (seed 12345), and MH_warm (seed 67890,
   warm-start) numV histograms.

   Writes:
     figures/is_vs_mh/q10_warm_vs_prod.png
     figures/is_vs_mh/q10_warm_vs_prod.pdf
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "lib_names.wl"}]];
dataDir = $CombDataDir;
figDir  = FileNameJoin[{$CombFiguresDir, "is_vs_mh"}];
If[!DirectoryQ[figDir], CreateDirectory[figDir]];

cells = {{3, 10, "unlabeled", 14}, {3, 10, "facet", 14},
         {4, 10, "unlabeled", 18}, {4, 10, "facet", 18}};

isFile[p_, q_, t_]     := combFile["isHist", p, q, t];
mhFile[p_, q_, t_]     := combFile["mh", p, q, t];
warmFile[p_, q_, t_, n_] := combFile["mh", p, q, t, combMHWarmTag[67890, n]];

binMh[mh_] := Module[{vals},
  vals = Select[mh["rows"][[All, 1]], NumericQ];
  If[Length[vals] == 0, <||>,
    KeySort @ N[Counts[vals] / Length[vals]]]];

l1[a_, b_] := Module[{keys, av, bv},
  keys = Sort @ Union[Keys[a], Keys[b]];
  av = Lookup[a, #, 0.] & /@ keys;
  bv = Lookup[b, #, 0.] & /@ keys;
  Total[Abs[av - bv]]];

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
