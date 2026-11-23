(* ::Package:: *)

(* Compare.wl: distances between sampled and exact distributions of the
   statistics of pure simplicial complexes, and weighted histograms of IS
   samples. Loaded by Kernel/CombResearch.wl into CombResearch`Private`;
   the public symbols are declared there.

   Moved in Phase 4 from the helpers that src/validate_mh_vs_truth.wl,
   src/compare_*.wl and src/precompute_is_histograms_q10.wl each defined
   for themselves (the drivers are now pipeline/50_validate.wl and
   pipeline/22_is_hists.wl). The arithmetic and its order are unchanged, so
   the summaries reproduce the stored ones exactly. *)

compareTruthPiKey = <|"vertex" -> "piVertex", "facet" -> "piFacet",
  "unlabeled" -> "piUnlabeled"|>;

(* Exact marginal of one statistic under a target, from a truth payload:
   iso classes grouped by the statistic's value, probabilities summed. *)
PureComplexTruthMarginal[truth_Association, target_String] :=
  PureComplexTruthMarginal[truth, target, "numV"];
PureComplexTruthMarginal[truth_Association, target_String, stat_String] := Module[
  {pi, vals},
  pi = truth[compareTruthPiKey[target]];
  vals = #["stats"][stat] & /@ truth["complexes"];
  Merge[Thread[vals -> pi], Total]];

(* Empirical histogram of samples: value -> fraction, numeric values only,
   sorted by value. With weights, the fraction is each value's share of the
   total weight (summed per value, then over values). *)
SampleHistogram[values_List] := Module[{vals = Select[values, NumericQ]},
  If[Length[vals] == 0, <||>, KeySort @ N[Counts[vals] / Length[vals]]]];
SampleHistogram[values_List, weights_List] := Module[{hist, total},
  hist = Total /@ GroupBy[Transpose[{values, weights}], First -> Last];
  total = Total[Values[hist]];
  KeySort @ AssociationThread[Keys[hist] -> Values[hist] / total]];

(* L1 distance of two histograms on the union of their values. *)
HistogramL1Distance[a_Association, b_Association] := Module[{keys, av, bv},
  keys = Sort @ Union[Keys[a], Keys[b]];
  av = Lookup[a, #, 0.] & /@ keys;
  bv = Lookup[b, #, 0.] & /@ keys;
  Total[Abs[av - bv]]];

(* Monte Carlo p-value of an observed L1 under iid sampling of size n
   from the discrete distribution `bars` (Association value -> prob). *)
Options[IIDL1PValue] = {"Replicates" -> 400};
IIDL1PValue[bars_Association, n_Integer, l1Obs_, OptionsPattern[]] := Module[
  {pv = Values[bars], sims, reps = OptionValue["Replicates"]},
  pv = pv / Total[pv];
  sims = Table[
    Total @ Abs[RandomVariate[MultinomialDistribution[n, pv]] / N[n] - pv],
    {reps}];
  N[Count[sims, x_ /; x >= l1Obs] / reps]];

(* Pearson chi-square on iso classes, pooling classes (sorted by expected
   count) until every bin has E >= 5. classIdx: the truth class of each
   sample, 0 for none. *)
IsoClassChiSquare[pi_List, classIdx_List] := Module[
  {n, obs, exp, ord, bins = {}, curO = 0, curE = 0., chi2, df},
  n = Count[classIdx, i_ /; i > 0];
  obs = Lookup[Counts[classIdx], Range[Length[pi]], 0];
  exp = n pi;
  ord = Ordering[exp];
  Do[
    curO += obs[[i]]; curE += exp[[i]];
    If[curE >= 5, AppendTo[bins, {curO, curE}]; curO = 0; curE = 0.],
    {i, ord}];
  If[curE > 0 && bins =!= {},
    bins[[-1]] += {curO, curE}];
  If[Length[bins] < 2, Return[<|"chi2" -> 0., "df" -> 0, "pValue" -> 1.,
    "bins" -> Length[bins]|>]];
  chi2 = Total[(#[[1]] - #[[2]])^2 / #[[2]] & /@ bins];
  df = Length[bins] - 1;
  <|"chi2" -> chi2, "df" -> df, "bins" -> Length[bins],
    "pValue" -> 1. - CDF[ChiSquareDistribution[df], chi2]|>];

(* Weighted histograms of every statistic of an IS sample, per target and
   per filter (all samples, connected ones), so figures never re-read the
   samples. rows: IS rows with the columns `headers` ($PureComplexISNames).
   Values that are not numbers (a Betti number that does not apply at this
   p) are left out; a statistic with none gets <||>. Weights are machine
   numbers: exact rationals are far too slow at 12M rows. *)
compareISWeightColumns = <|"vertex" -> "wVertex", "unlabeled" -> "wUnlabeled",
  "facet" -> "wFacet"|>;
PureComplexStatisticHistograms[headers_List, rows_List] := Module[
  {col, w, conn, filters, stats, hists, ess, counts},
  col = AssociationThread[headers -> Range[Length[headers]]];
  w = AssociationMap[N[rows[[All, col[compareISWeightColumns[#]]]]] &,
    Keys[compareISWeightColumns]];
  conn = rows[[All, col["connected"]]];
  filters = <|"all" -> Range[Length[rows]],
    "connected" -> Flatten[Position[conn, 1, {1}, Heads -> False]]|>;
  stats = Select[$PureComplexStatisticNames, KeyExistsQ[col, #] &];
  counts = Length /@ filters;
  ess = AssociationMap[Function[f,
      AssociationMap[EffectiveSampleSize[w[#][[filters[f]]]] &, Keys[w]]],
    Keys[filters]];
  hists = AssociationMap[Function[s,
      AssociationMap[Function[f, Module[{idx = filters[f], vals, keep},
          vals = rows[[idx, col[s]]];
          keep = Flatten[Position[NumericQ /@ vals, True, {1}, Heads -> False]];
          AssociationMap[
            If[keep === {}, <||>,
              SampleHistogram[vals[[keep]], w[#][[idx]][[keep]]]] &,
            Keys[w]]]],
        Keys[filters]]],
    stats];
  <|"sourceN" -> Length[rows], "filters" -> Keys[filters],
    "targets" -> Keys[w], "statistics" -> stats,
    "n" -> counts, "ESS" -> ess, "hists" -> hists|>];
