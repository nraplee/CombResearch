(* golden_quick.wl
   golden/quick (Phase 3): checks a store made by the quick profile,
     wolframscript -file run.wl all profile quick
   in a fresh COMB_ROOT. See tests/golden/README.md.

     $env:COMB_ROOT = "<quick store>"; wolframscript -file tests\golden\golden_quick.wl
     wolframscript -file tests\golden\golden_quick.wl write     (freeze; reads the main store;
                                                         write force to overwrite)

   Rules (implementation-plan.md, Phase 0 "golden/quick"):
     truth      must match exactly: the (2,4) and (3,4) truth (iso classes,
                their stats, piVertex/piFacet/piUnlabeled, counts), frozen from
                the main store's truth in tests/golden/quick/truth.wxf. Compared
                order-independently: the list of {stats, piV, piF, piU} rows,
                sorted.
     samplers   within tolerance of truth, not equal to earlier values (ECGrav
                keeps changing): numV-marginal L1 from the store's
                validation_{source}_summary.wxf, every cell x target present.
                Tolerances are per sampler, for the quick budget: exact 0.05
                (N=5000 iid), ecgmcmc 0.10 (N=2000), MH 0.15 (20k iterations,
                thin 5; correlated). A broken sampler is far outside these (the
                pre-fix vertex chains were at 0.85).
     IS         at the truth cells, the vertex target (ESS = N) within 0.05 of
                truth (is_mh_truth_3way_summary); unlabeled/facet reported only
                (ESS collapse, docs/sampling.md).
     q=10 IS    each quick batch has N rows and the 15-column schema.
     manifests  every data output has a real-run manifest (not backfilled),
                with profile "quick" and the ECGrav commit recorded.
   Exit 0 pass, 1 fail, 2 missing inputs. *)

$code = ParentDirectory[DirectoryName[$InputFileName], 2];
Get[FileNameJoin[{$code, "src", "lib_names.wl"}]];
Get[FileNameJoin[{$code, "src", "lib_io.wl"}]];

$frozen = FileNameJoin[{DirectoryName[$InputFileName], "quick", "truth.wxf"}];
$cells = {{2, 4}, {3, 4}};
$targets = {"unlabeled", "facet", "vertex"};
(* the q=10 IS schema ($CombISHeaders in src/lib_stats.wl; not loaded here, it
   loads ECGrav) *)
$isHeaders = {"numV", "aut", "autF", "connected", "num1VConnComps", "num2VConnComps",
  "largestCompRatio", "num2PathConnComps", "num3PathConnComps", "Betti1", "Betti2", "Betti3",
  "wVertex", "wUnlabeled", "wFacet"};
$tol = <|"ecgexact" -> 0.05, "ecgmcmc" -> 0.10, "mh" -> 0.15, "isVertex" -> 0.05|>;

truthKey[t_Association] := <|"numIsoClasses" -> t["numIsoClasses"],
  "totalFacetLabeled" -> t["totalFacetLabeled"],
  "rows" -> Sort[Transpose[{#["stats"] & /@ t["complexes"], t["piVertex"], t["piFacet"],
    t["piUnlabeled"]}]]|>;

If[MemberQ[Rest[$ScriptCommandLine], "write"],
  Module[{fr},
    (* the frozen truth must come from the main store, never a scratch root *)
    If[StringQ[Environment["COMB_ROOT"]] && Environment["COMB_ROOT"] =!= "",
      Print["golden_quick write: unset COMB_ROOT; the truth is frozen from the main store"]; Exit[2]];
    If[FileExistsQ[$frozen] && !MemberQ[Rest[$ScriptCommandLine], "force"],
      Print["golden_quick write: ", $frozen, " exists; add 'force' to overwrite"]; Exit[2]];
    If[!AllTrue[$cells, FileExistsQ[combFile["truth", #[[1]], #[[2]]]] &],
      Print["golden_quick write: truth missing in ", $CombDataDir]; Exit[2]];
    fr = AssociationMap[truthKey[Import[combFile["truth", #[[1]], #[[2]]], "WXF"]] &, $cells];
    If[!AllTrue[fr, AssociationQ[#] && ListQ[#["rows"]] &],
      Print["golden_quick write: could not read the truth files"]; Exit[2]];
    If[!DirectoryQ[DirectoryName[$frozen]], CreateDirectory[DirectoryName[$frozen]]];
    Export[$frozen, <|"truth" -> fr, "madeFrom" -> $CombDataDir, "createdAt" -> DateString["ISODateTime"]|>,
      "WXF"];
    Print["golden_quick: froze truth for ", $cells, " from ", $CombDataDir, " -> ", $frozen];
    Exit[0]]];

$fail = 0; $missing = 0;
check[label_, ok_, detail_ : ""] := If[TrueQ[ok], Print["ok    ", label, " ", detail],
  $fail++; Print["FAIL  ", label, " ", detail]];
need[f_] := If[FileExistsQ[f], True, $missing++; Print["MISSING ", f]; False];

Print["golden_quick: store ", $CombDataDir];
If[!need[$frozen], Exit[2]];
frozen = Import[$frozen, "WXF"]["truth"];

(* truth *)
Do[If[need[combFile["truth", c[[1]], c[[2]]]],
    check["truth " <> ToString[c], truthKey[Import[combFile["truth", c[[1]], c[[2]]], "WXF"]] === frozen[c],
      "(exact match with the frozen store truth)"]], {c, $cells}];

(* samplers *)
Do[With[{f = combFile["validationSummary", s]},
    If[need[f], Module[{res = Import[f, "WXF"]["results"], got},
      Do[got = SelectFirst[res, #["p"] == c[[1]] && #["q"] == c[[2]] && #["target"] === t &, None];
        check[s <> " " <> ToString[c] <> " " <> t,
          AssociationQ[got] && NumericQ[got["l1"]] && got["l1"] < $tol[s],
          If[AssociationQ[got], "L1 = " <> ToString[NumberForm[got["l1"], {4, 3}]] <>
            " (< " <> ToString[$tol[s]] <> ")", "(no row)"]],
        {c, $cells}, {t, $targets}]]]],
  {s, {"ecgexact", "ecgmcmc", "mh"}}];

(* IS at the truth cells *)
With[{f = combFile["summary", "is_mh_truth_3way"]},
  If[need[f], Module[{res = Import[f, "WXF"]["results"], got},
    Do[got = SelectFirst[res, #["p"] == c[[1]] && #["q"] == c[[2]] && #["target"] === t &, None];
      If[t === "vertex",
        check["IS " <> ToString[c] <> " vertex", AssociationQ[got] && got["l1IsTruth"] < $tol["isVertex"],
          If[AssociationQ[got], "L1 = " <> ToString[NumberForm[got["l1IsTruth"], {4, 3}]], "(no row)"]],
        If[AssociationQ[got], Print["info  IS ", c, " ", t, "  L1 = ", ToString[NumberForm[got["l1IsTruth"], {4, 3}]],
          "  ESS = ", Round[got["isESS"]], " (reported only)"]]],
      {c, $cells}, {t, $targets}]]]];

(* q=10 IS batches *)
Do[With[{f = combFile["isStats", combISStem[p, 10, 2000, None, "quick"]]},
    If[need[f], With[{x = Import[f, "WXF"]},
      check["q=10 IS p=" <> ToString[p], Length[x["rows"]] == 2000 && x["headers"] === $isHeaders && AllTrue[x["rows"], Length[#] == 15 &] &&
          AllTrue[x["rows"][[All, 13 ;; 15]], AllTrue[#, NumericQ] &],
        "(2000 rows, " <> ToString[Length[x["headers"]]] <> " columns)"]]]],
  {p, {2, 3, 4}}];

(* q=10 statistic histograms (pipeline/22_is_hists.wl): every statistic,
   normalized, and the all-samples numV fractions = the numV hist's *)
Do[With[{f = combFile["isStatHists", p, 10], h = combFile["isHist", p, 10, "unlabeled"]},
    If[need[f] && need[h], With[{x = Import[f, "WXF"], y = Import[h, "WXF"]["fracHist"]},
      With[{u = x["hists"]["numV"]["all"]["unlabeled"]},
        check["q=10 stat hists p=" <> ToString[p],
          x["statistics"] === Take[$isHeaders, 12] && x["sourceN"] == 2000 &&
            Keys[u] === Keys[y] && Max[Abs[Values[u] - Values[y]]] < 10^-12 &&
            AllTrue[Flatten[Values /@ Values /@ Values[x["hists"]]],
              # === <||> || Abs[Total[#] - 1] < 10^-9 &],
          "(" <> ToString[Length[x["statistics"]]] <> " statistics x 3 targets x 2 filters)"]]]]],
  {p, {2, 3, 4}}];

(* results tables (validate's results job) *)
Do[With[{f = combFile["results", n]},
    If[need[f], With[{t = Import[f, "CSV"]},
      check["results " <> n, Length[t] >= 2 && MemberQ[First[t], "p"],
        "(" <> ToString[Length[t] - 1] <> " rows)"]]]],
  {n, {"counts_vs_truth", "validation_mh", "validation_ecgexact", "validation_ecgmcmc",
    "sampler_efficiency", "is_mh_truth_3way"}}];  (* quick makes no q=10 MH, so no q10_is_vs_mh *)

(* manifests *)
Module[{outs, bad},
  outs = Select[FileNames["*.wxf", $CombDataDir], !StringContainsQ[#, "_chunk_"] &];
  bad = Select[outs, With[{m = combManifest[#]},
      !AssociationQ[m] || m["backfilled"] =!= False || m["profile"] =!= "quick" ||
        (StringStartsQ[FileNameTake[#], "p"] && StringContainsQ[FileNameTake[#], "_ecg" | "_mh_" | "_truth"] &&
          !StringQ[m["ecgravCommit"]])] &];
  check["manifests", outs =!= {} && bad === {},
    ToString[Length[outs]] <> " outputs" <> If[bad === {}, "", "; bad: " <>
      StringRiffle[FileNameTake /@ bad, ", "]]]];

Print[""];
Which[
  $missing > 0, Print["golden_quick: ", $missing, " input(s) missing"]; Exit[2],
  $fail > 0, Print["golden_quick: FAILED ", $fail]; Exit[1],
  True, Print["golden_quick: PASS"]; Exit[0]];
