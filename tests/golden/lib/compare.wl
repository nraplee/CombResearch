(* tests/golden/lib/compare.wl
   Helpers shared by the golden sections "compare" and "efficiency".
   Each helper is a verbatim copy of the consumer script's code at
   bd355d2 (same operation order, same N[] placement), so the frozen values
   equal what the scripts compute bit-for-bit. Helpers that differ between
   scripts are kept as separate copies under distinct names.

   Never Get src/sampler_mh.wl here: it loads ECGrav. *)

(* ----- compare_3way / render_3way / compare_q10_warm_vs_prod /
         render_q10_warm_vs_prod / compare_is_mh_q10 / render_q10_is_vs_mh *)

(* from src/compare_3way.wl:42-43 at bd355d2 (same in render_3way.wl:24-25) *)
gcPiKey = <|"vertex" -> "piVertex", "facet" -> "piFacet",
            "unlabeled" -> "piUnlabeled"|>;

(* from src/compare_3way.wl:45-48 at bd355d2 (same in render_3way.wl:27-30) *)
gcMarginalizeTruth[truth_, t_] := Module[{pi, numVs},
  pi = truth[gcPiKey[t]];
  numVs = #["stats"]["numV"] & /@ truth["complexes"];
  Total /@ GroupBy[Transpose[{numVs, pi}], First -> Last]];

(* from src/compare_3way.wl:50-53 at bd355d2; identical in render_3way.wl:32-35,
   compare_is_mh_q10.wl:43-46, render_q10_is_vs_mh.wl:21-24,
   compare_q10_warm_vs_prod.wl:37-40, render_q10_warm_vs_prod.wl:28-31 *)
gcBinMh[mh_] := Module[{vals},
  vals = Select[mh["rows"][[All, 1]], NumericQ];
  If[Length[vals] == 0, <||>,
    KeySort @ N[Counts[vals] / Length[vals]]]];

(* from src/compare_3way.wl:55-59 at bd355d2; identical in render_3way.wl:37-41,
   compare_q10_warm_vs_prod.wl:42-46, render_q10_warm_vs_prod.wl:33-37 *)
gcL1[a_, b_] := Module[{keys, av, bv},
  keys = Sort @ Union[Keys[a], Keys[b]];
  av = Lookup[a, #, 0.] & /@ keys;
  bv = Lookup[b, #, 0.] & /@ keys;
  Total[Abs[av - bv]]];

(* from src/compare_is_mh_q10.wl:48-55 at bd355d2 *)
gcCmpBars[isBars_, mhBars_] := Module[{keys, iv, mv, diffs, l1},
  keys  = Sort @ Union[Keys[isBars], Keys[mhBars]];
  iv    = Lookup[isBars, #, 0.] & /@ keys;
  mv    = Lookup[mhBars, #, 0.] & /@ keys;
  diffs = Abs[iv - mv];
  l1    = Total[diffs];
  <|"keys" -> keys, "is" -> iv, "mh" -> mv, "diff" -> diffs,
    "l1" -> l1|>];

(* ----- compare_samplers_efficiency ----- *)

(* from src/sampler_mh.wl:377-391 at bd355d2 (verbatim; do not Get
   sampler_mh.wl, it loads ECGrav) *)
gcIntegratedAutocorrTime[x_List] := Module[{n, mu, var, c, k, sum},
  n = Length[x];
  mu = Mean[N[x]];
  var = Variance[N[x]];
  If[var == 0., Return[<|"tau" -> Infinity, "ess" -> 0|>]];
  sum = 0.5;
  k = 1;
  While[k < n - 1,
    c = Mean[(x[[1 ;; n - k]] - mu) * (x[[1 + k ;; n]] - mu)] / var;
    If[c <= 0, Break[]];
    sum += c;
    k++];
  <|"tau" -> sum, "ess" -> N[n / (2 sum)], "lagsUsed" -> k|>
];

(* from src/compare_samplers_efficiency.wl:68-76 at bd355d2 *)
geUnweightedHist[x_List] := N[Counts[x] / Length[x]];
geWeightedHist[x_List, w_List] := Module[{m = Merge[Thread[x -> w], Total]},
  N[m / Total[w]]];
geL1[a_Association, b_Association] := With[{ks = Union[Keys[a], Keys[b]]},
  Total[Abs[Lookup[a, ks, 0.] - Lookup[b, ks, 0.]]]];
geKish[w_List] := N[Total[w]^2 / Total[w^2]];

geTruthMarginal[truth_, target_] := Merge[
  Thread[(#["nV"] & /@ truth["complexes"]) -> truth[gcPiKey[target]]], Total];

(* from src/compare_samplers_efficiency.wl:79-84 at bd355d2 *)
geRow[src_, n_, wall_, ess_, l1v_, extra_:<||>] := Join[<|
  "source" -> src, "n" -> n, "wall" -> wall, "ess" -> ess,
  "essFrac" -> If[NumericQ[ess] && n > 0, ess / n, Missing[]],
  "essPerSec" -> If[NumericQ[ess] && NumericQ[wall] && wall > 0,
    ess / wall, Missing[]],
  "l1" -> l1v|>, extra];

(* from src/compare_samplers_efficiency.wl:86-97 at bd355d2 *)
geChainRow[src_, payload_, ref_] := Module[{x, ac, extra = <||>},
  x = payload["rows"][[All, 1]];
  ac = gcIntegratedAutocorrTime[x];
  If[KeyExistsQ[payload, "traceNumV"],
    With[{act = gcIntegratedAutocorrTime[payload["traceNumV"]]},
      extra = <|"tauPerSweepTrace" -> act["tau"],
        "corrT" -> payload["corrT"], "eqlT" -> payload["eqlT"],
        "traceEssPerSec" -> If[payload["traceSeconds"] > 0,
          act["ess"] / payload["traceSeconds"], Missing[]]|>]];
  geRow[src, Length[x], payload["wallSeconds"], ac["ess"],
    If[AssociationQ[ref], geL1[geUnweightedHist[x], ref], Missing["NoRef"]],
    Join[<|"tau" -> ac["tau"]|>, extra]]];

(* from src/compare_samplers_efficiency.wl:100-108 at bd355d2 *)
geIsWeights[rows_, q_, "unlabeled"] := MapThread[#2 / #1! &,
  {rows[[All, 1]], rows[[All, 2]]}];
geIsWeights[rows_, q_, "facet"] := MapThread[#2 q! / (#3 #1!) &,
  {rows[[All, 1]], rows[[All, 2]], rows[[All, 3]]}];
geIsRow[src_, rows_, q_, target_, wall_, ref_] := Module[{w},
  w = N @ geIsWeights[rows, q, target];
  geRow[src, Length[rows], wall, geKish[w],
    If[AssociationQ[ref], geL1[geWeightedHist[rows[[All, 1]], w], ref],
      Missing["NoRef"]]]];

(* ----- golden bookkeeping ----- *)

(* Stored summary row for (match criteria) from a summary's "results". *)
gcStoredRow[summary_, crit_Association] := SelectFirst[summary["results"],
  AllTrue[Keys[crit], Function[k, #[k] === crit[k]]] &, Missing["NotStored"]];

(* Add storedSummaryMatch (and the differing field names when False) by
   comparing the recomputed summary row with the stored one exactly. *)
gcWithStoredMatch[rec_Association, now_Association, stored_] := Module[{ok},
  ok = AssociationQ[stored] && now === stored;
  Join[rec, <|"storedSummaryMatch" -> ok|>,
    If[ok, <||>, <|"storedSummaryMismatchFields" ->
      If[AssociationQ[stored],
        Select[Union[Keys[now], Keys[stored]],
          Lookup[now, #] =!= Lookup[stored, #] &],
        "noStoredRow"]|>]]];

(* Stale pre-fix vertex MH chains frozen as they are (AGENTS.md; acceptRate 1.,
   L1 vs truth 0.68-0.85). *)
gcStaleVertexMh = {{2, 4}, {2, 5}, {2, 6}, {3, 4}, {3, 5}};
gcKnownBadMh[p_, q_, t_] := If[t === "vertex" && MemberQ[gcStaleVertexMh, {p, q}],
  <|"knownBad" -> "stale pre-fix vertex MH chain p" <> ToString[p] <> "q" <>
    ToString[q] <> "_mh_vertex.wxf (pi_V proportional to 1, acceptRate 1.); " <>
    "made before the 2026-05-15 vertex fix"|>, <||>];

(* Panel record plus its content hash. *)
gcWithHash[rec_Association] := Append[rec, "hash" -> goldenHash[rec]];
