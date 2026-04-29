(* render_uniformity_check.wl
   Per-iso-class uniformity check of the MH sampler at p=2 q=4.
   For each MH state, identify which iso class it matches, then plot
   visit-count histograms vs theoretical truth.

     Panel A: target="unlabeled" — truth is uniform 1/11 per iso class.
     Panel B: target="facet"     — truth is q!/|Aut_F([Y])| per iso class
                                   (normalized).

   Output: figures/sampler_mh_uniformity.{pdf,png} *)

Needs["ECGrav`"];
$smokeTestSkip = True;
Get["src/sampler_mh.wl"];

(* ===== Enumerate iso classes at p=2 q=4 ===== *)
Print["enumerating p=2 q=4 ..."];
allLab = GenerateAllFacetLabeledPureSimplicialComplexes[{2, 4}];
isoClasses = ChooseNonIsomorphicSimplicialComplexes[allLab];
nIso = Length[isoClasses];
isoNumVs  = Length[DeleteDuplicates[Flatten[#]]] & /@ isoClasses;
isoAuts   = PureComplexAutomorphismGroupOrder /@ isoClasses;
isoAutFs  = PureComplexFacetAutomorphismGroupOrder /@ isoClasses;
Print["  ", nIso, " iso classes"];
Print["  numV per iso  : ", isoNumVs];
Print["  |Aut| per iso : ", isoAuts];
Print["  |Aut_F| per iso: ", isoAutFs];

(* Sort iso classes by (numV, |Aut|) for readable plot ordering. *)
sortOrder = Ordering[Transpose[{isoNumVs, isoAuts}]];
isoClasses = isoClasses[[sortOrder]];
isoNumVs   = isoNumVs[[sortOrder]];
isoAuts    = isoAuts[[sortOrder]];
isoAutFs   = isoAutFs[[sortOrder]];

(* Group iso indices by numV for fast matching *)
indicesByNumV = GroupBy[Range[nIso], isoNumVs[[#]] &];

(* Map an MH state to its iso class index. Filter candidates by numV first
   so we only do iso checks against ~3 candidates instead of all 11. *)
matchIsoClass[X_List] := Module[{m, candidates, hit},
  m = Length[DeleteDuplicates[Flatten[X]]];
  candidates = Lookup[indicesByNumV, m, {}];
  hit = SelectFirst[candidates,
    IsomorphicSimplicialComplexQ[X, isoClasses[[#]]] &, Missing[]];
  hit];

(* ===== Run unlabeled MH and match ===== *)
Print["[A] target=unlabeled, 30k+3k burn ..."];
resU = runMHChain[2, 4, "unlabeled", 30000, burnIn -> 3000, verbose -> False];
matchU = matchIsoClass /@ resU["trace"];
nMissing = Count[matchU, _Missing];
If[nMissing > 0, Print["  WARNING: ", nMissing, " states unmatched (bug!)"]];
empU = Counts[matchU];
empUFracs = N[(Lookup[empU, #, 0] & /@ Range[nIso]) / Length[matchU]];
truthU = ConstantArray[N[1/nIso], nIso];

(* ===== Run facet MH and match ===== *)
Print["[B] target=facet, 30k+3k burn ..."];
resF = runMHChain[2, 4, "facet", 30000, burnIn -> 3000, verbose -> False];
matchF = matchIsoClass /@ resF["trace"];
nMissingF = Count[matchF, _Missing];
If[nMissingF > 0, Print["  WARNING: ", nMissingF, " states unmatched (bug!)"]];
empF = Counts[matchF];
empFFracs = N[(Lookup[empF, #, 0] & /@ Range[nIso]) / Length[matchF]];
fLabelCounts = N[4! / isoAutFs];
truthF = fLabelCounts / Total[fLabelCounts];

(* ===== Diagnostic prints ===== *)
Print["unlabeled empirical vs truth (per iso class):"];
Do[Print["  iso ", i, " (numV=", isoNumVs[[i]], "): emp=",
  NumberForm[empUFracs[[i]], {5, 4}],
  "  truth=", NumberForm[truthU[[i]], {5, 4}]],
  {i, nIso}];
Print["facet empirical vs truth (per iso class):"];
Do[Print["  iso ", i, " (numV=", isoNumVs[[i]],
  ", |Aut_F|=", isoAutFs[[i]],
  "): emp=", NumberForm[empFFracs[[i]], {5, 4}],
  "  truth=", NumberForm[truthF[[i]], {5, 4}]],
  {i, nIso}];

(* ===== Plot ===== *)
fontFam = "Times"; fontSz = 10;
panelSize = {500, 320};
truthColor = RGBColor[0.122, 0.471, 0.706];
mhColor    = RGBColor[0.890, 0.290, 0.200];

panelStyle[plot_, title_] := Show[plot,
  PlotLabel -> Style[title, FontFamily -> fontFam, FontSize -> fontSz + 1],
  BaseStyle -> {FontFamily -> fontFam, FontSize -> fontSz},
  ImageSize -> panelSize];

(* Annotate iso classes with numV for readability *)
labelsX = ("[" <> ToString[#] <> "]" &) /@ Range[nIso];

panelU = panelStyle[
  BarChart[Transpose[{truthU, empUFracs}],
    ChartLabels -> {Placed[labelsX, Below], None},
    ChartLegends -> Placed[{"truth (uniform = 1/11)", "MH unlabeled (30k)"}, Top],
    ChartStyle -> {truthColor, mhColor},
    Frame -> True, FrameLabel -> {"iso class index", "fraction of samples"},
    PlotRange -> {0, Automatic}],
  "p=2 q=4 — target=unlabeled (truth: uniform on 11 iso classes)"];

panelF = panelStyle[
  BarChart[Transpose[{truthF, empFFracs}],
    ChartLabels -> {Placed[labelsX, Below], None},
    ChartLegends -> Placed[{"truth ∝ q!/|Aut_F|", "MH facet (30k)"}, Top],
    ChartStyle -> {truthColor, mhColor},
    Frame -> True, FrameLabel -> {"iso class index", "fraction of samples"},
    PlotRange -> {0, Automatic}],
  "p=2 q=4 — target=facet (truth ∝ q!/|Aut_F|)"];

If[!DirectoryQ["figures"], CreateDirectory["figures"]];
fig = Grid[{{panelU}, {panelF}}, Spacings -> {0, 1}];
Export["figures/sampler_mh_uniformity.pdf", fig];
Export["figures/sampler_mh_uniformity.png", fig, ImageResolution -> 150];
Print["wrote figures/sampler_mh_uniformity.{pdf,png}"];
