(* compare_samplers_efficiency.wl
   ESS / cost / accuracy table across every sampler we have, per
   (p, q) × target. The numV marginal is the observable throughout, as in
   Phase 4.

   Sources (each included only if its WXF exists):
     mh            data/p{p}q{q}_mh_{target}.wxf           our sampler_mh.wl chains
     ecgmcmc       data/p{p}q{q}_ecgmcmc_{target}.wxf      ECGrav RandomPureSimplicialComplexMCMC
     ecgexact      data/p{p}q{q}_ecgexact_{target}.wxf     ECGrav exact samplers
     is-ecgvertex  data/p{p}q{q}_ecgexact_vertex.wxf       old IS reweighting applied to the
                                                           ECGrav vertex draws (unlabeled/facet)
     is-legacy     data/p{p}q10_merged_stats.wxf           the Phase 3 q=10 IS runs (q=10 only)

   ESS:
     mh, ecgmcmc, ecgexact : n / (2 τ_int) on the numV sequence
                             (integratedAutocorrTime, sampler_mh.wl). For
                             ecgexact this should be ≈ N (τ ≈ 0.5): the
                             independence check.
     is-*                  : Kish (Σw)² / Σw².
   ecgmcmc also reports τ_int per sweep from its separate trace, and
   ECGrav's own corrT.

   Accuracy: numV L1 against the truth marginal when data/p{p}q{q}_truth.wxf
   exists, otherwise against the ecgexact histogram (the q=10 reference).
   For ecgexact without truth, a split-half L1 is reported as the noise
   floor of that reference.

   Wall seconds are sampling time only (stats computation excluded) and
   are machine- and load-dependent; compare within one table only.

   Env: COMB_EFF_CELLS ("p,q;..."), COMB_EFF_TARGETS.
   Output: data/sampler_efficiency_summary.wxf + printed table.
*)

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
Get[FileNameJoin[{scriptDir, "comb_paths.wl"}]];
Get[FileNameJoin[{scriptDir, "lib_names.wl"}]];
Get[FileNameJoin[{scriptDir, "lib_config.wl"}]];
dataDir = $CombDataDir;

Get[FileNameJoin[{scriptDir, "load_ecgrav.wl"}]];
$smokeTestSkip = True;
Get[FileNameJoin[{scriptDir, "sampler_mh.wl"}]];   (* integratedAutocorrTime *)

defaultCells = {{2, 4}, {2, 5}, {2, 6}, {2, 7},
                {3, 4}, {3, 5}, {3, 6},
                {4, 4}, {4, 5},
                {2, 10}, {3, 10}, {4, 10}};
defaultTargets = {"unlabeled", "facet", "vertex"};
piKey = <|"vertex" -> "piVertex", "facet" -> "piFacet",
          "unlabeled" -> "piUnlabeled"|>;

resolvedCells   = combSetting["COMB_EFF_CELLS", defaultCells, "cells"];
resolvedTargets = combSetting["COMB_EFF_TARGETS", defaultTargets, "list"];

loadIf[f_] := If[FileExistsQ[f], Import[f, "WXF"], Missing["NoFile"]];

(* ----- histograms and distances ----- *)
unweightedHist[x_List] := N[Counts[x] / Length[x]];
weightedHist[x_List, w_List] := Module[{m = Merge[Thread[x -> w], Total]},
  N[m / Total[w]]];
l1[a_Association, b_Association] := With[{ks = Union[Keys[a], Keys[b]]},
  Total[Abs[Lookup[a, ks, 0.] - Lookup[b, ks, 0.]]]];
kish[w_List] := N[Total[w]^2 / Total[w^2]];

truthMarginal[truth_, target_] := Merge[
  Thread[(#["nV"] & /@ truth["complexes"]) -> truth[piKey[target]]], Total];

(* ----- one row per source ----- *)
row[src_, n_, wall_, ess_, l1v_, extra_:<||>] := Join[<|
  "source" -> src, "n" -> n, "wall" -> wall, "ess" -> ess,
  "essFrac" -> If[NumericQ[ess] && n > 0, ess / n, Missing[]],
  "essPerSec" -> If[NumericQ[ess] && NumericQ[wall] && wall > 0,
    ess / wall, Missing[]],
  "l1" -> l1v|>, extra];

chainRow[src_, payload_, ref_] := Module[{x, ac, extra = <||>},
  x = payload["rows"][[All, 1]];
  ac = integratedAutocorrTime[x];
  If[KeyExistsQ[payload, "traceNumV"],
    With[{act = integratedAutocorrTime[payload["traceNumV"]]},
      extra = <|"tauPerSweepTrace" -> act["tau"],
        "corrT" -> payload["corrT"], "eqlT" -> payload["eqlT"],
        "traceEssPerSec" -> If[payload["traceSeconds"] > 0,
          act["ess"] / payload["traceSeconds"], Missing[]]|>]];
  row[src, Length[x], payload["wallSeconds"], ac["ess"],
    If[AssociationQ[ref], l1[unweightedHist[x], ref], Missing["NoRef"]],
    Join[<|"tau" -> ac["tau"]|>, extra]]];

(* IS from vertex draws. rows: {numV, aut, autF, ...}. *)
isWeights[rows_, q_, "unlabeled"] := MapThread[#2 / #1! &,
  {rows[[All, 1]], rows[[All, 2]]}];
isWeights[rows_, q_, "facet"] := MapThread[#2 q! / (#3 #1!) &,
  {rows[[All, 1]], rows[[All, 2]], rows[[All, 3]]}];
isRow[src_, rows_, q_, target_, wall_, ref_] := Module[{w},
  w = N @ isWeights[rows, q, target];
  row[src, Length[rows], wall, kish[w],
    If[AssociationQ[ref], l1[weightedHist[rows[[All, 1]], w], ref],
      Missing["NoRef"]]]];

processCellTarget[p_, q_, target_] := Module[
  {truth, mh, mc, ex, vx, legacy, ref, refName, out = {}, halves},
  truth  = loadIf[combFile["truth", p, q]];
  mh     = loadIf[combFile["mh", p, q, target]];
  mc     = loadIf[combFile["ecg", p, q, "mcmc", target]];
  ex     = loadIf[combFile["ecg", p, q, "exact", target]];
  vx     = loadIf[combFile["ecg", p, q, "exact", "vertex"]];
  legacy = If[q == 10, loadIf[combFile["isStats", combMergedStem[p, q]]], Missing[]];

  {ref, refName} = Which[
    AssociationQ[truth], {truthMarginal[truth, target], "truth"},
    AssociationQ[ex], {unweightedHist[ex["rows"][[All, 1]]], "ecgexact"},
    True, {Missing["NoRef"], "none"}];

  If[AssociationQ[mh], AppendTo[out, chainRow["mh", mh, ref]]];
  If[AssociationQ[mc], AppendTo[out, chainRow["ecgmcmc", mc, ref]]];
  If[AssociationQ[ex],
    AppendTo[out, chainRow["ecgexact", ex, If[refName === "ecgexact",
      Missing["IsRef"], ref]]];
    If[refName === "ecgexact",
      halves = Partition[ex["rows"][[All, 1]], Floor[Length[ex["rows"]]/2]];
      out[[-1]] = Append[out[[-1]], "splitHalfL1" ->
        l1[unweightedHist[halves[[1]]], unweightedHist[halves[[2]]]]]]];
  If[AssociationQ[vx] && target =!= "vertex",
    AppendTo[out, isRow["is-ecgvertex", vx["rows"], q, target,
      vx["wallSeconds"], ref]]];
  If[AssociationQ[legacy] && target =!= "vertex",
    (* legacy columns 14/15 are wUnlabeled/wFacet *)
    With[{w = N @ legacy["rows"][[All, If[target === "unlabeled", 14, 15]]],
          x = legacy["rows"][[All, 1]]},
      AppendTo[out, row["is-legacy", Length[x], Missing["Unrecorded"],
        kish[w], If[AssociationQ[ref], l1[weightedHist[x, w], ref],
          Missing["NoRef"]]]]]];
  If[AssociationQ[legacy] && target === "vertex",
    With[{x = legacy["rows"][[All, 1]]},
      AppendTo[out, row["direct-legacy", Length[x], Missing["Unrecorded"],
        Length[x], If[AssociationQ[ref], l1[unweightedHist[x], ref],
          Missing["NoRef"]]]]]];
  <|"p" -> p, "q" -> q, "target" -> target, "reference" -> refName,
    "rows" -> out|>];

fmt[x_?NumericQ, d_:4] := ToString[NumberForm[N[x], {8, d},
  ExponentFunction -> (If[-5 < # < 7, Null, #] &)]];
fmt[x_, _:4] := "-";

results = {};
Do[
  Do[
    With[{r = processCellTarget[cell[[1]], cell[[2]], t]},
      If[r["rows"] =!= {}, AppendTo[results, r]]],
    {t, resolvedTargets}],
  {cell, resolvedCells}];

Print[""];
Print[StringPadRight["cell", 8], StringPadRight["target", 11],
  StringPadRight["source", 14], StringPadRight["N", 9],
  StringPadRight["wall s", 10], StringPadRight["ESS", 11],
  StringPadRight["ESS/N", 9], StringPadRight["ESS/s", 11],
  StringPadRight["L1", 9], "ref / notes"];
Do[
  Do[
    Print[
      StringPadRight["(" <> ToString[r["p"]] <> "," <> ToString[r["q"]] <> ")", 8],
      StringPadRight[r["target"], 11],
      StringPadRight[s["source"], 14],
      StringPadRight[ToString[s["n"]], 9],
      StringPadRight[fmt[s["wall"], 1], 10],
      StringPadRight[fmt[s["ess"], 0], 11],
      StringPadRight[fmt[s["essFrac"], 3], 9],
      StringPadRight[fmt[s["essPerSec"], 1], 11],
      StringPadRight[fmt[s["l1"], 4], 9],
      r["reference"],
      If[KeyExistsQ[s, "tau"], "  tau=" <> fmt[s["tau"], 2], ""],
      If[KeyExistsQ[s, "corrT"], "  corrT=" <> ToString[s["corrT"]] <>
        " tau/sweep=" <> fmt[s["tauPerSweepTrace"], 2], ""],
      If[KeyExistsQ[s, "splitHalfL1"], "  splitHalfL1=" <>
        fmt[s["splitHalfL1"], 4], ""]],
    {s, r["rows"]}],
  {r, results}];

Export[combFile["summary", "sampler_efficiency"],
  <|"results" -> results, "ecGravVersion" -> $CombECGravVersion,
    "createdAt" -> DateString[]|>, "WXF"];
Print[""];
Print["wrote data/sampler_efficiency_summary.wxf"];
