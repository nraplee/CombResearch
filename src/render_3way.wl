(* render_3way.wl
   2x3 grid of overlay panels: rows = cells {(3,5),(4,5)}, cols =
   targets {vertex, unlabeled, facet}. Each panel overlays IS, MH, and
   truth as grouped bars.

   Writes:
     figures/q5_is_mh_truth_3way.png
     figures/q5_is_mh_truth_3way.pdf
*)

dataDir = "C:/CombResearch/data";
figDir  = "C:/CombResearch/figures";
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

panel[p_, q_, t_] := Module[
  {is, mh, truth, isBars, mhBars, tBars, keys, isV, mhV, tV,
   l1IsT, l1MhT, ess, title},
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

  BarChart[
    Transpose[{tV, isV, mhV}],
    ChartLayout -> "Grouped",
    ChartStyle -> {
      Directive[Opacity[0.95], Black],
      Directive[Opacity[0.85], RGBColor[0.20, 0.45, 0.85]],
      Directive[Opacity[0.85], RGBColor[0.85, 0.40, 0.20]]},
    ChartLegends -> Placed[{"truth", "IS reweighted", "MH chain"}, Top],
    ChartLabels -> {ToString /@ keys, None},
    Frame -> True,
    FrameLabel -> {"numV", "fraction"},
    PlotLabel -> Style[title, 10],
    ImageSize -> 520]];

cells = {{3, 5}, {4, 5}};
targets = {"vertex", "unlabeled", "facet"};

Print["Rendering 2x3 3-way grid..."];
panels = Table[panel[cell[[1]], cell[[2]], t],
  {cell, cells}, {t, targets}];
grid = Grid[panels, Spacings -> {0.5, 0.5},
  Frame -> All, FrameStyle -> LightGray];

Export[FileNameJoin[{figDir, "q5_is_mh_truth_3way.png"}], grid,
  ImageResolution -> 144];
Print["wrote figures/q5_is_mh_truth_3way.png"];

Export[FileNameJoin[{figDir, "q5_is_mh_truth_3way.pdf"}], grid];
Print["wrote figures/q5_is_mh_truth_3way.pdf"];

Print["Done."];
