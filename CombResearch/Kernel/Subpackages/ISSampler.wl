(* ::Package:: *)

(* ISSampler.wl: importance sampling of pure simplicial complexes from
   ECGrav's vertex-labeled sampler, reweighted to the three targets.
   Loaded by Kernel/CombResearch.wl into CombResearch`Private`; the public
   symbols are declared there.

   Moved in Phase 4 from the per-chunk loop of src/pure_simplicial_compute.wl
   (the driver itself is now pipeline/20_is_q10.wl). The formulas and the
   order of operations are unchanged, so seeded runs reproduce the stored
   rows exactly.

   A sample from RandomVertexLabeledPureSimplicialComplex[{p, q}] is uniform
   over vertex-labeled complexes, so the iso class X has probability
   proportional to numV(X)! / |Aut(X)|. Weights that turn it into each target:
     vertex     w = 1
     unlabeled  w = |Aut(X)| / numV(X)!                 (uniform over classes)
     facet      w = |Aut(X)| q! / (|Aut_F(X)| numV(X)!) (uniform over
                                                         facet-labeled)
   Exact rationals, as stored. *)

$PureComplexISNames = Join[$PureComplexStatisticNames, {"wVertex", "wUnlabeled", "wFacet"}];

isWeightRows[statsRows_List, q_Integer] := Module[{numVs, auts, autFs, wV, wU, wF, n},
  n = Length[statsRows];
  numVs = statsRows[[All, 1]];
  auts  = statsRows[[All, 2]];
  autFs = statsRows[[All, 3]];
  wV = ConstantArray[1, n];
  wU = MapThread[#1 / #2! &, {auts, numVs}];
  wF = MapThread[#1 * q! / (#2 * #3!) &, {auts, autFs, numVs}];
  MapThread[Join[#1, {#2, #3, #4}] &, {statsRows, wV, wU, wF}]];

PureComplexISWeights[statsRows : {__List}, q_Integer] := isWeightRows[statsRows, q];

Options[PureComplexISSample] = {"Parallel" -> False};

(* spec = {p, q} or {p, q, numV}; the caller seeds (SeedRandom) first. *)
PureComplexISSample[spec : {_Integer, _Integer} | {_Integer, _Integer, _Integer},
    n_Integer?Positive, OptionsPattern[]] := Module[{p = spec[[1]], q = spec[[2]], sample, statsRows},
  sample = RandomVertexLabeledPureSimplicialComplex[spec, n];
  statsRows = If[TrueQ[OptionValue["Parallel"]],
    ParallelMap[statsFor[#, p] &, sample],
    statsFor[#, p] & /@ sample];
  <|"complexes" -> sample, "rows" -> isWeightRows[statsRows, q]|>];

(* Kish effective sample size of a weight vector. *)
EffectiveSampleSize[w_List] := With[{s2 = Total[w^2]}, If[s2 == 0, 0, N[Total[w]^2 / s2]]];
