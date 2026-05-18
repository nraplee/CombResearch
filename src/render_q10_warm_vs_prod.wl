(* render_q10_warm_vs_prod.wl
   2x2 grid (rows = p in {3,4}, cols = target in {unlabeled, facet})
   overlaying IS, MH_prod (seed 12345), and MH_warm (seed 67890,
   warm-start) numV histograms.

   Writes:
     figures/q10_warm_vs_prod.png
     figures/q10_warm_vs_prod.pdf
*)

dataDir = "C:/CombResearch/data";
figDir  = "C:/CombResearch/figures";
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

panel[p_, q_, t_, nW_] := Module[
  {is, prod, warm, isBars, prodBars, warmBars,
   keys, isV, pV, wV, l1PW, l1IsP, l1IsW, title},
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

  BarChart[
    Transpose[{isV, pV, wV}],
    ChartLayout -> "Grouped",
    ChartStyle -> {
      Directive[Opacity[0.85], RGBColor[0.20, 0.45, 0.85]],     (* IS *)
      Directive[Opacity[0.85], RGBColor[0.85, 0.40, 0.20]],     (* prod *)
      Directive[Opacity[0.85], RGBColor[0.20, 0.65, 0.30]]},    (* warm *)
    ChartLegends -> Placed[{"IS", "MH prod (seed12345)",
                            "MH warm (seed67890 warm-init)"}, Top],
    ChartLabels -> {ToString /@ keys, None},
    Frame -> True,
    FrameLabel -> {"numV", "fraction"},
    PlotLabel -> Style[title, 10],
    ImageSize -> 560]];

Print["Rendering 2x2 warm-vs-prod grid..."];
panels = Partition[panel @@@ cells, 2];
grid = Grid[panels, Spacings -> {0.5, 0.5},
  Frame -> All, FrameStyle -> LightGray];

Export[FileNameJoin[{figDir, "q10_warm_vs_prod.png"}], grid,
  ImageResolution -> 144];
Print["wrote figures/q10_warm_vs_prod.png"];
Export[FileNameJoin[{figDir, "q10_warm_vs_prod.pdf"}], grid];
Print["wrote figures/q10_warm_vs_prod.pdf"];
Print["Done."];
