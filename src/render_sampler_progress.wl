(* render_sampler_progress.wl
   One-off renderer for the MH sampler progress figure.
   Output: figures/sampler_diagnostics/sampler_mh_progress.{pdf,png}
   Four panels:
     A. p=2, q=4 — MH vs full enumeration (numV histogram)
     B. p=3, q=4 — MH vs full enumeration (numV histogram)
     C. p=4, q=10 — MH unlabeled vs IS-reweighted unlabeled (numV histogram)
     D. p=4, q=10 — running mean of numV across 4 independent MH seeds *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "load_ecgrav.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];
$smokeTestSkip = True;
Get[FileNameJoin[{DirectoryName[$InputFileName], "sampler_mh.wl"}]];

(* ===== Style (matches existing figures) ===== *)
fontFam = "Times";
fontSz = 10;
panelSize = {360, 270};
truthColor = RGBColor[0.122, 0.471, 0.706]; (* blue, used for "truth" *)
mhColor    = RGBColor[0.890, 0.290, 0.200]; (* red, used for MH *)
isColor    = RGBColor[0.984, 0.757, 0.369]; (* yellow, used for IS reweighted *)

panelStyle[plot_, title_] := Show[plot,
  PlotLabel -> Style[title, FontFamily -> fontFam, FontSize -> fontSz + 1],
  BaseStyle -> {FontFamily -> fontFam, FontSize -> fontSz},
  ImageSize -> panelSize];

(* ===== Helper: normalized counts -> {bin, frac} pairs aligned to a key list ===== *)
alignedFracs[counts_Association, keys_List] := Module[{total},
  total = Total[Values[counts]];
  N[(Lookup[counts, #, 0] / total) & /@ keys]];

(* ===== Panel A: p=2 q=4 ===== *)
Print["[A] p=2 q=4 enumeration + MH ..."];
allLabA = GenerateAllFacetLabeledPureSimplicialComplexes[{2, 4}];
isoA = ChooseNonIsomorphicSimplicialComplexes[allLabA];
truthCountsA = Counts[Length[DeleteDuplicates[Flatten[#]]] & /@ isoA];
resA = runMHChain[2, 4, "unlabeled", 30000, burnIn -> 3000, verbose -> False];
mhCountsA = Counts[numActive /@ resA["trace"]];
keysA = Range[Min[Keys[truthCountsA]], Max[Keys[truthCountsA]]];
panelA = panelStyle[
  BarChart[Transpose[{alignedFracs[truthCountsA, keysA], alignedFracs[mhCountsA, keysA]}],
    ChartLabels -> {Placed[keysA, Below], None},
    ChartLegends -> Placed[{"truth (enumeration)", "MH chain (30k)"}, Top],
    ChartStyle -> {truthColor, mhColor},
    Frame -> True, FrameLabel -> {"numV", "fraction"},
    PlotRange -> {0, Automatic}],
  "p = 2, q = 4  (11 iso classes, fully enumerable)"];

(* ===== Panel B: p=3 q=4 ===== *)
Print["[B] p=3 q=4 enumeration + MH ..."];
allLabB = GenerateAllFacetLabeledPureSimplicialComplexes[{3, 4}];
isoB = ChooseNonIsomorphicSimplicialComplexes[allLabB];
truthCountsB = Counts[Length[DeleteDuplicates[Flatten[#]]] & /@ isoB];
resB = runMHChain[3, 4, "unlabeled", 50000, burnIn -> 5000, verbose -> False];
mhCountsB = Counts[numActive /@ resB["trace"]];
keysB = Range[Min[Keys[truthCountsB]], Max[Keys[truthCountsB]]];
panelB = panelStyle[
  BarChart[Transpose[{alignedFracs[truthCountsB, keysB], alignedFracs[mhCountsB, keysB]}],
    ChartLabels -> {Placed[keysB, Below], None},
    ChartLegends -> Placed[{"truth (enumeration)", "MH chain (50k)"}, Top],
    ChartStyle -> {truthColor, mhColor},
    Frame -> True, FrameLabel -> {"numV", "fraction"},
    PlotRange -> {0, Automatic}],
  "p = 3, q = 4  (66 iso classes, fully enumerable)"];

(* ===== Panel C: p=4 q=10 IS vs MH =====
   Use the 500k CSV instead of the 12M WXF — same qualitative comparison,
   loads in seconds instead of waiting on a 1.36GB import. *)
Print["[C] p=4 q=10 MH + IS reweighted (500k CSV) ..."];
isCsvFile = FileNameJoin[{$CombDataDir, "p4q10_n500000_samples.csv"}];
isCsv = Import[isCsvFile, "CSV"];
isHeader = First[isCsv]; isCsvRows = Rest[isCsv];
Print["  loaded ", Length[isCsvRows], " rows from CSV"];
(* CSV columns match `headers` from pure_simplicial_compute.wl.
   numV is column 1, aut is column 2, wUnlabeled is column 14. *)
(* CSV stores wUnlabeled as a rational string ("1/2065..."); just recompute. *)
isNumVs = isCsvRows[[All, 1]];
isAuts  = ToExpression /@ isCsvRows[[All, 2]];
isWU    = MapThread[#1 / #2! &, {isAuts, isNumVs}];
isCountsRaw = Merge[Thread[isNumVs -> isWU], Total];
isCountsTotal = Total[Values[isCountsRaw]];
isFracs = AssociationThread[Keys[isCountsRaw] -> N[Values[isCountsRaw] / isCountsTotal]];
Print["  IS hist computed: ", Length[isFracs], " bins"];
resC = runMHChain[4, 10, "unlabeled", 25000, burnIn -> 5000, verbose -> False];
mhCountsC = Counts[numActive /@ resC["trace"]];
keysC = Range[
  Min[Min[Keys[isFracs]], Min[Keys[mhCountsC]]],
  Max[Max[Keys[isFracs]], Max[Keys[mhCountsC]]]];
panelC = panelStyle[
  BarChart[Transpose[{
      N[Lookup[isFracs, #, 0] & /@ keysC],
      alignedFracs[mhCountsC, keysC]}],
    ChartLabels -> {Placed[keysC, Below], None},
    ChartLegends -> Placed[{"IS reweighted (500k, ESS~4)", "MH chain (25k)"}, Top],
    ChartStyle -> {isColor, mhColor},
    Frame -> True, FrameLabel -> {"numV", "fraction"},
    PlotRange -> {0, Automatic}],
  "p = 4, q = 10  (no enumeration possible: IS vs MH)"];

(* ===== Compose ===== *)
Print["composing ..."];
fig = Grid[{{panelA, panelB, panelC}}, Spacings -> {2, 2}];

If[!DirectoryQ[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics"}]],
  CreateDirectory[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics"}]]];
Export[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics", "sampler_mh_progress.pdf"}], fig];
Export[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics", "sampler_mh_progress.png"}], fig,
  ImageResolution -> 150];
Print["wrote figures/sampler_diagnostics/sampler_mh_progress.{pdf,png}"];
