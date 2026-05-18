(* render_q10_is_vs_mh.wl
   Render a 3x3 grid (rows = p in {2,3,4}, cols = target in
   {vertex, unlabeled, facet}) of overlay panels comparing the
   IS-reweighted numV histogram against the MH-sampled one at q=10.

   Writes:
     figures/q10_is_vs_mh_grid.png
     figures/q10_is_vs_mh_grid.pdf
*)

dataDir = "C:/CombResearch/data";
figDir  = "C:/CombResearch/figures";
If[!DirectoryQ[figDir], CreateDirectory[figDir]];

isFile[p_, t_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q10_is_" <> t <> "_numv_hist.wxf"}];
mhFile[p_, t_] := FileNameJoin[{dataDir,
  "p" <> ToString[p] <> "q10_mh_" <> t <> ".wxf"}];

binMh[mh_Association] := Module[{vals},
  vals = Select[mh["rows"][[All, 1]], NumericQ];
  If[Length[vals] == 0, <||>,
    KeySort @ N[Counts[vals] / Length[vals]]]];

panel[p_, target_] := Module[
  {is, mh, isBars, mhBars, keys, isV, mhV, l1, ess, niter, acc,
   pts, title, leg},
  is = Import[isFile[p, target], "WXF"];
  mh = Import[mhFile[p, target], "WXF"];
  isBars = is["fracHist"];
  mhBars = binMh[mh];
  keys = Sort @ Union[Keys[isBars], Keys[mhBars]];
  isV  = Lookup[isBars, #, 0.] & /@ keys;
  mhV  = Lookup[mhBars, #, 0.] & /@ keys;
  l1   = Total[Abs[isV - mhV]];
  ess  = is["ESS"];
  niter = mh["numIter"];
  acc  = mh["acceptRate"];
  title = Row[{
    "p=", p, ", target=", target,
    "  |  L1=", NumberForm[l1, {4, 3}],
    "  IS ESS=", NumberForm[ess, 3],
    "  MH n=", niter,
    "  acc=", NumberForm[acc, {3, 2}]}];
  BarChart[
    Transpose[{isV, mhV}],
    ChartLayout -> "Grouped",
    ChartStyle -> {Directive[Opacity[0.85], RGBColor[0.20, 0.45, 0.85]],
                   Directive[Opacity[0.85], RGBColor[0.85, 0.40, 0.20]]},
    ChartLegends -> Placed[{"IS reweighted", "MH chain"}, Top],
    ChartLabels -> {ToString /@ keys, None},
    Frame -> True,
    FrameLabel -> {"numV", "fraction"},
    PlotLabel -> Style[title, 10],
    ImageSize -> 480,
    PlotRangePadding -> {Scaled[0.02], Scaled[0.05]}]];

ps = {2, 3, 4};
targets = {"vertex", "unlabeled", "facet"};

Print["Rendering 3x3 grid..."];
panels = Table[panel[p, t], {p, ps}, {t, targets}];
grid = Grid[panels, Spacings -> {0.5, 0.5}, Frame -> All,
  FrameStyle -> LightGray];

Export[FileNameJoin[{figDir, "q10_is_vs_mh_grid.png"}], grid,
  ImageResolution -> 144];
Print["wrote figures/q10_is_vs_mh_grid.png"];

Export[FileNameJoin[{figDir, "q10_is_vs_mh_grid.pdf"}], grid];
Print["wrote figures/q10_is_vs_mh_grid.pdf"];

(* Also render a focused 1x2 panel: (4,10) unlabeled and facet, the
   most-dramatic disagreement cells, for the writeup. *)
focus = Grid[{{panel[4, "unlabeled"], panel[4, "facet"]}},
  Spacings -> 0.5];
Export[FileNameJoin[{figDir, "q10_p4_focus.png"}], focus,
  ImageResolution -> 144];
Print["wrote figures/q10_p4_focus.png"];

Print["Done."];
