(* tests/golden/sections/efficiency.wl
   Freezes the ESS / cost / accuracy table of src/compare_samplers_efficiency.wl
   (code at bd355d2) for the 9 truth cells x 3 targets, from the store as it
   is today. Its q=10 branch (merged IS stats, ecgexact reference, split-half
   L1) never ran and is excluded.

   One record per cell x target, "eff|p{p}q{q}|{target}", holding the
   script's own result <|p, q, target, reference, rows|>; each row is
   {source, n, wall, ess, essFrac, essPerSec, l1, tau, mcmc extras} with
   wall = the stored wallSeconds, so everything is deterministic.

   storedSummaryMatch compares each result with the stored entry of
   data/sampler_efficiency_summary.wxf exactly. Records built from the stale
   pre-fix vertex MH chains carry "knownBad". *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "compare.wl"}]];

(* from src/compare_samplers_efficiency.wl:45-49 at bd355d2, truth cells only *)
effCells = {{2, 4}, {2, 5}, {2, 6}, {2, 7},
            {3, 4}, {3, 5}, {3, 6},
            {4, 4}, {4, 5}};
effTargets = {"unlabeled", "facet", "vertex"};

effName[p_, q_, suffix_] := "p" <> ToString[p] <> "q" <> ToString[q] <> "_" <> suffix <> ".wxf";

(* loadIf (compare_samplers_efficiency.wl:65) over the store: a file is used
   only if it exists. *)
effExisting := effExisting = goldenGlob["p*q*_*.wxf"];
effHave[name_] := MemberQ[effExisting, name];
effLoadIf[name_] := If[effHave[name], goldenImport[name], Missing["NoFile"]];

(* Files processCellTarget reads for a cell x target (q != 10). *)
effInputs[p_, q_, target_] := Select[
  {effName[p, q, "truth"], effName[p, q, "mh_" <> target],
   effName[p, q, "ecgmcmc_" <> target], effName[p, q, "ecgexact_" <> target],
   effName[p, q, "ecgexact_vertex"]}, effHave];

(* from src/compare_samplers_efficiency.wl:110-149 at bd355d2; the q == 10
   legacy branches (l.117, 136-147) are dropped: legacy is Missing[] for
   every truth cell. *)
effProcessCellTarget[p_, q_, target_] := Module[
  {truth, mh, mc, ex, vx, ref, refName, out = {}, halves},
  truth  = effLoadIf[effName[p, q, "truth"]];
  mh     = effLoadIf[effName[p, q, "mh_" <> target]];
  mc     = effLoadIf[effName[p, q, "ecgmcmc_" <> target]];
  ex     = effLoadIf[effName[p, q, "ecgexact_" <> target]];
  vx     = effLoadIf[effName[p, q, "ecgexact_vertex"]];

  {ref, refName} = Which[
    AssociationQ[truth], {geTruthMarginal[truth, target], "truth"},
    AssociationQ[ex], {geUnweightedHist[ex["rows"][[All, 1]]], "ecgexact"},
    True, {Missing["NoRef"], "none"}];

  If[AssociationQ[mh], AppendTo[out, geChainRow["mh", mh, ref]]];
  If[AssociationQ[mc], AppendTo[out, geChainRow["ecgmcmc", mc, ref]]];
  If[AssociationQ[ex],
    AppendTo[out, geChainRow["ecgexact", ex, If[refName === "ecgexact",
      Missing["IsRef"], ref]]];
    If[refName === "ecgexact",
      halves = Partition[ex["rows"][[All, 1]], Floor[Length[ex["rows"]]/2]];
      out[[-1]] = Append[out[[-1]], "splitHalfL1" ->
        geL1[geUnweightedHist[halves[[1]]], geUnweightedHist[halves[[2]]]]]]];
  If[AssociationQ[vx] && target =!= "vertex",
    AppendTo[out, geIsRow["is-ecgvertex", vx["rows"], q, target,
      vx["wallSeconds"], ref]]];
  <|"p" -> p, "q" -> q, "target" -> target, "reference" -> refName,
    "rows" -> out|>];

goldenSection["efficiency"] := Module[{summary, records = <||>, r, stored},
  summary = goldenImport["sampler_efficiency_summary.wxf"];
  Do[
    Do[
      r = effProcessCellTarget[cell[[1]], cell[[2]], t];
      stored = gcStoredRow[summary,
        <|"p" -> cell[[1]], "q" -> cell[[2]], "target" -> t|>];
      records["eff|p" <> ToString[cell[[1]]] <> "q" <> ToString[cell[[2]]] <>
          "|" <> t] = Join[
        gcWithStoredMatch[r, r, stored],
        If[effHave[effName[cell[[1]], cell[[2]], "mh_" <> t]],
          gcKnownBadMh[cell[[1]], cell[[2]], t], <||>]],
      {t, effTargets}];
    (* Free the cell's chains (each ~4 MB on disk) before the next cell. *)
    Scan[goldenForget,
      Union @@ (effInputs[cell[[1]], cell[[2]], #] & /@ effTargets)],
    {cell, effCells}];
  <|"inputs" -> Prepend[
      Flatten[Table[effInputs[c[[1]], c[[2]], t], {c, effCells}, {t, effTargets}]],
      "sampler_efficiency_summary.wxf"],
    "records" -> records|>];
