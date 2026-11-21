(* render_ecgrav_compare.wl
   Compare ECGrav's RandomFacetLabeledPureSimplicialComplex (the
   "unverified" sampler we're forbidden from using in the production
   pipeline) against the MH facet target and the q!/|Aut_F| truth.

   Three series per iso class at p=2 q=4:
     - truth (q!/|Aut_F| normalized)
     - MH facet (30k)
     - ECGrav RandomFacetLabeled (30k)

   If ECGrav's sampler IS uniform on facet-labelings, all three should
   match. Any systematic deviation in the ECGrav bars from truth is
   evidence that the sampler is biased.

   Output: figures/sampler_diagnostics/sampler_ecgrav_compare.{pdf,png} *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "load_ecgrav.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];
$smokeTestSkip = True;
Get[FileNameJoin[{DirectoryName[$InputFileName], "sampler_mh.wl"}]];

Print["enumerating p=2 q=4 ..."];
isoClasses = ChooseNonIsomorphicSimplicialComplexes[
  GenerateAllFacetLabeledPureSimplicialComplexes[{2, 4}]];
nIso = Length[isoClasses];
isoNumVs = Length[DeleteDuplicates[Flatten[#]]] & /@ isoClasses;
isoAutFs = PureComplexFacetAutomorphismGroupOrder /@ isoClasses;

(* Sort by (numV, |Aut_F|) for readable plot ordering *)
sortOrder = Ordering[Transpose[{isoNumVs, isoAutFs}]];
isoClasses = isoClasses[[sortOrder]];
isoNumVs = isoNumVs[[sortOrder]];
isoAutFs = isoAutFs[[sortOrder]];
indicesByNumV = GroupBy[Range[nIso], isoNumVs[[#]] &];

matchIso[X_List] := Module[{m, cands},
  m = Length[DeleteDuplicates[Flatten[X]]];
  cands = Lookup[indicesByNumV, m, {}];
  SelectFirst[cands, IsomorphicSimplicialComplexQ[X, isoClasses[[#]]] &, Missing[]]];

(* === MH facet === *)
Print["MH facet 30k+3k burn ..."];
mhRes = runMHChain[2, 4, "facet", 30000, burnIn -> 3000, verbose -> False];
mhMatches = matchIso /@ mhRes["trace"];
mhCounts = Counts[mhMatches];
mhFracs = N[(Lookup[mhCounts, #, 0] & /@ Range[nIso]) / Length[mhMatches]];

(* === ECGrav RandomFacetLabeled === *)
Print["ECGrav RandomFacetLabeledPureSimplicialComplex 30k ..."];
SeedRandom[2024];
ecSamples = RandomFacetLabeledPureSimplicialComplex[{2, 4}, 30000];
ecMatches = matchIso /@ ecSamples;
nMissing = Count[ecMatches, _Missing];
If[nMissing > 0, Print["  WARNING: ", nMissing, " ECGrav samples unmatched"]];
ecCounts = Counts[ecMatches];
ecFracs = N[(Lookup[ecCounts, #, 0] & /@ Range[nIso]) / Length[ecMatches]];

(* === Truth === *)
truthRaw = N[4!/isoAutFs];
truthFracs = truthRaw / Total[truthRaw];

(* === Diagnostic prints === *)
Print["per-iso-class fractions (truth | MH facet | ECGrav):"];
Do[Print["  iso ", i, " (numV=", isoNumVs[[i]], ", |Aut_F|=", isoAutFs[[i]],
  "):  ", NumberForm[truthFracs[[i]], {5, 4}],
  "  ", NumberForm[mhFracs[[i]], {5, 4}],
  "  ", NumberForm[ecFracs[[i]], {5, 4}]],
  {i, nIso}];

(* L1 distance to truth *)
Print["L1 distance to truth:"];
Print["  MH facet  : ", N[Total[Abs[mhFracs - truthFracs]]]];
Print["  ECGrav    : ", N[Total[Abs[ecFracs - truthFracs]]]];

(* === Plot === *)
fontFam = "Times"; fontSz = 10;
truthColor = RGBColor[0.122, 0.471, 0.706];
mhColor = RGBColor[0.890, 0.290, 0.200];
ecColor = RGBColor[0.4, 0.7, 0.3];

labelsX = ("[" <> ToString[#] <> "]" &) /@ Range[nIso];

panel = Show[
  BarChart[Transpose[{truthFracs, mhFracs, ecFracs}],
    ChartLabels -> {Placed[labelsX, Below], None},
    ChartLegends -> Placed[
      {"truth (q!/|Aut_F|)", "MH facet (30k)", "ECGrav RandomFacetLabeled (30k)"},
      Top],
    ChartStyle -> {truthColor, mhColor, ecColor},
    Frame -> True, FrameLabel -> {"iso class index", "fraction of samples"},
    PlotRange -> {0, Automatic}],
  PlotLabel -> Style[
    "p=2 q=4: MH facet vs ECGrav RandomFacetLabeled vs truth",
    FontFamily -> fontFam, FontSize -> fontSz + 1],
  BaseStyle -> {FontFamily -> fontFam, FontSize -> fontSz},
  ImageSize -> {800, 400}];

If[!DirectoryQ[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics"}]],
  CreateDirectory[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics"}]]];
Export[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics", "sampler_ecgrav_compare.pdf"}], panel];
Export[FileNameJoin[{$CombFiguresDir, "sampler_diagnostics", "sampler_ecgrav_compare.png"}], panel,
  ImageResolution -> 150];
Print["wrote figures/sampler_diagnostics/sampler_ecgrav_compare.{pdf,png}"];
