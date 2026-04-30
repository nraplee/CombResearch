(* benchmark_kernels_uniformity.wl
   At p=2 q=4 (11 iso classes), run target=unlabeled with each of the 4
   proposal kernels and measure how well each visits all 11 classes.
   The benchmark question: which kernel best fixes the iso-11 (matching)
   undersampling we found with the global kernel?

   For each kernel, report L1 distance to the uniform truth (1/11 per
   class) and per-class deviation. *)

Needs["ECGrav`"];
$smokeTestSkip = True;
Get["src/sampler_mh.wl"];

(* Enumerate iso classes *)
isoClasses = ChooseNonIsomorphicSimplicialComplexes[
  GenerateAllFacetLabeledPureSimplicialComplexes[{2, 4}]];
nIso = Length[isoClasses];
isoNumVs = Length[DeleteDuplicates[Flatten[#]]] & /@ isoClasses;
isoAuts = PureComplexAutomorphismGroupOrder /@ isoClasses;

sortOrder = Ordering[Transpose[{isoNumVs, isoAuts}]];
isoClasses = isoClasses[[sortOrder]];
isoNumVs = isoNumVs[[sortOrder]];
isoAuts = isoAuts[[sortOrder]];
indicesByNumV = GroupBy[Range[nIso], isoNumVs[[#]] &];

matchIso[X_List] := Module[{m, cands},
  m = Length[DeleteDuplicates[Flatten[X]]];
  cands = Lookup[indicesByNumV, m, {}];
  SelectFirst[cands, IsomorphicSimplicialComplexQ[X, isoClasses[[#]]] &, Missing[]]];

truth = ConstantArray[N[1/nIso], nIso];

Print["p=2 q=4 iso-class coverage by proposal kernel"];
Print["target=unlabeled, 30k+3k burn"];
Print["================================================================="];

Do[Module[{t, res, matches, nMissing, fracs, l1, dev11},
  t = First @ AbsoluteTiming[
    res = runMHChain[2, 4, "unlabeled", 30000, burnIn -> 3000,
      kernel -> kn, verbose -> False]];
  matches = matchIso /@ res["trace"];
  nMissing = Count[matches, _Missing];
  fracs = N[(Lookup[Counts[matches], #, 0] & /@ Range[nIso]) / Length[matches]];
  l1 = N[Total[Abs[fracs - truth]]];
  dev11 = (fracs[[11]] - truth[[11]]) / truth[[11]] * 100;
  Print["kernel=", kn];
  Print["  wall-clock     : ", N[t], " s"];
  Print["  accept rate    : ", N[res["acceptRate"]]];
  Print["  L1 to uniform  : ", l1];
  Print["  iso-11 (matching) deviation: ", N[dev11], " %"];
  If[nMissing > 0, Print["  WARNING: ", nMissing, " unmatched"]];
  Print["  per-class fractions: ", NumberForm[#, {5, 4}] & /@ fracs];
  Print[""]],
  {kn, {"global", "local", "swap", "mixed"}}];
