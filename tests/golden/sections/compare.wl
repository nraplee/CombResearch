(* tests/golden/sections/compare.wl
   Freezes the numV-marginal comparison tables and the binned data of the
   IS / MH / truth overlay figures, from the store as it is today.

   Scripts replicated (code at bd355d2):
     src/compare_3way.wl            6 rows  "3way|p{p}q5|{target}"
     src/render_3way.wl             6 panels "render3way|p{p}q5|{target}"
     src/compare_is_mh_q10.wl       9 rows  "q10|p{p}|{target}"
     src/render_q10_is_vs_mh.wl     9 grid panels "q10grid|p{p}|{target}"
                                    + 2 focus panels "q10focus|p4|{target}"
     src/compare_q10_warm_vs_prod.wl 4 rows "warm|p{p}q10|{target}"
     src/render_q10_warm_vs_prod.wl 4 panels "renderwarm|p{p}q10|{target}"

   Table rows hold every L1 plus the aligned keys/bar vectors.
   Panel records hold exactly what the render plots: the keys, the bar
   vectors fed to WeightedData, the bin spec {lo - 0.5, hi + 0.5, 1}, the
   overlay points, the label numbers, and "hash" = goldenHash of the rest.
   The renders' alignment code is the same as their compare scripts'.

   storedSummaryMatch compares each recomputed table row with the stored
   row in is_mh_truth_3way_summary.wxf / q10_is_vs_mh_summary.wxf /
   q10_warm_vs_prod_summary.wxf exactly. A False is a finding, not a bug
   in this file: the (3,5) vertex 3-way row was made from
   p3q5_mh_vertex.2026-05-17.wxf.bak, while the store's
   p3q5_mh_vertex.wxf is the stale pre-fix chain ("knownBad"). *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "compare.wl"}]];

cmpName[p_, q_, suffix_] := "p" <> ToString[p] <> "q" <> ToString[q] <> "_" <> suffix <> ".wxf";

(* ----- compare_3way.wl / render_3way.wl ----- *)

(* from src/compare_3way.wl:71-122 at bd355d2 (per cell x target) *)
cmp3way[p_, q_, t_] := Module[{truth, isData, mh, isBars, mhBars, tBars, keys,
    isV, mhV, tV, l1IsT, l1MhT, l1IsMh, ess, niter, acc, row, stored},
  truth  = goldenImport[cmpName[p, q, "truth"]];
  isData = goldenImport[cmpName[p, q, "is_" <> t <> "_numv_hist"]];
  mh     = goldenImport[cmpName[p, q, "mh_" <> t]];
  isBars = isData["fracHist"];
  mhBars = gcBinMh[mh];
  tBars  = gcMarginalizeTruth[truth, t];
  keys = Sort @ Union[Keys[isBars], Keys[mhBars], Keys[tBars]];
  isV  = Lookup[isBars, #, 0.] & /@ keys;
  mhV  = Lookup[mhBars, #, 0.] & /@ keys;
  tV   = N @ Lookup[tBars,  #, 0.] & /@ keys;
  l1IsT  = gcL1[isBars, tBars];
  l1MhT  = gcL1[mhBars, tBars];
  l1IsMh = gcL1[isBars, mhBars];
  ess   = isData["ESS"];
  niter = mh["numIter"];
  acc   = mh["acceptRate"];
  row = <|"p" -> p, "q" -> q, "target" -> t,
    "l1IsTruth" -> l1IsT, "l1MhTruth" -> l1MhT,
    "l1IsMh"    -> l1IsMh,
    "isN" -> isData["sourceN"], "isESS" -> ess,
    "mhIter" -> niter, "mhAccept" -> acc|>;
  stored = gcStoredRow[goldenImport["is_mh_truth_3way_summary.wxf"],
    <|"p" -> p, "q" -> q, "target" -> t|>];
  Join[gcWithStoredMatch[
      Join[row, <|"keys" -> keys, "is" -> isV, "mh" -> mhV, "truth" -> tV|>],
      row, stored],
    gcKnownBadMh[p, q, t]]];

(* from src/render_3way.wl:83-119 at bd355d2 (panel[p, q, t]) *)
panel3way[p_, q_, t_] := Module[{is, mh, truth, isBars, mhBars, tBars, keys,
    isV, mhV, tV, l1IsT, l1MhT, ess, lo, hi, truthPts},
  is    = goldenImport[cmpName[p, q, "is_" <> t <> "_numv_hist"]];
  mh    = goldenImport[cmpName[p, q, "mh_" <> t]];
  truth = goldenImport[cmpName[p, q, "truth"]];
  isBars = is["fracHist"];
  mhBars = gcBinMh[mh];
  tBars  = gcMarginalizeTruth[truth, t];
  keys = Sort @ Union[Keys[isBars], Keys[mhBars], Keys[tBars]];
  isV  = Lookup[isBars, #, 0.] & /@ keys;
  mhV  = Lookup[mhBars, #, 0.] & /@ keys;
  tV   = N @ Lookup[tBars, #, 0.] & /@ keys;
  l1IsT = gcL1[isBars, tBars];
  l1MhT = gcL1[mhBars, tBars];
  ess   = is["ESS"];
  lo = First[keys]; hi = Last[keys];
  truthPts = Pick[Transpose[{keys, tV}], # > 0 & /@ tV];
  Join[gcWithHash[<|"figure" -> "is_vs_mh/q5_is_mh_truth_3way",
      "keys" -> keys, "bins" -> {lo - 0.5, hi + 0.5, 1},
      "bars" -> <|"IS" -> isV, "MH" -> mhV|>, "points" -> truthPts,
      "label" -> <|"l1IsTruth" -> l1IsT, "l1MhTruth" -> l1MhT, "isESS" -> ess|>|>],
    gcKnownBadMh[p, q, t]]];

(* ----- compare_is_mh_q10.wl / render_q10_is_vs_mh.wl ----- *)

(* from src/compare_is_mh_q10.wl:89-115 at bd355d2 *)
cmpQ10[p_, t_] := Module[{isData, mhData, cmp, ess, acc, niter, row, stored},
  isData = goldenImport[cmpName[p, 10, "is_" <> t <> "_numv_hist"]];
  mhData = goldenImport[cmpName[p, 10, "mh_" <> t]];
  cmp    = gcCmpBars[isData["fracHist"], gcBinMh[mhData]];
  ess    = isData["ESS"];
  acc    = mhData["acceptRate"];
  niter  = mhData["numIter"];
  row = <|"p" -> p, "target" -> t,
    "l1" -> cmp["l1"], "isESS" -> ess, "mhIter" -> niter,
    "acceptRate" -> acc|>;
  stored = gcStoredRow[goldenImport["q10_is_vs_mh_summary.wxf"],
    <|"p" -> p, "target" -> t|>];
  gcWithStoredMatch[Join[row, KeyDrop[cmp, "l1"]], row, stored]];

(* from src/render_q10_is_vs_mh.wl:48-84 at bd355d2 (panel[p, target]) *)
panelQ10[fig_, p_, t_] := Module[{is, mh, isBars, mhBars, keys, isV, mhV,
    l1val, ess, niter, acc, lo, hi},
  is = goldenImport[cmpName[p, 10, "is_" <> t <> "_numv_hist"]];
  mh = goldenImport[cmpName[p, 10, "mh_" <> t]];
  isBars = is["fracHist"];
  mhBars = gcBinMh[mh];
  keys = Sort @ Union[Keys[isBars], Keys[mhBars]];
  isV  = Lookup[isBars, #, 0.] & /@ keys;
  mhV  = Lookup[mhBars, #, 0.] & /@ keys;
  l1val = Total[Abs[isV - mhV]];
  ess   = is["ESS"];
  niter = mh["numIter"];
  acc   = mh["acceptRate"];
  lo = First[keys]; hi = Last[keys];
  gcWithHash[<|"figure" -> fig,
    "keys" -> keys, "bins" -> {lo - 0.5, hi + 0.5, 1},
    "bars" -> <|"IS" -> isV, "MH" -> mhV|>, "points" -> {},
    "label" -> <|"l1" -> l1val, "isESS" -> ess, "mhIter" -> niter,
      "acceptRate" -> acc|>|>]];

(* ----- compare_q10_warm_vs_prod.wl / render_q10_warm_vs_prod.wl ----- *)

(* from src/compare_q10_warm_vs_prod.wl:25-26 at bd355d2
   (duplicated in render_q10_warm_vs_prod.wl:16-17) *)
warmCells = {{3, 10, "unlabeled", 14}, {3, 10, "facet", 14},
             {4, 10, "unlabeled", 18}, {4, 10, "facet", 18}};
warmName[p_, q_, t_, n_] := cmpName[p, q, "mh_" <> t <> "_seed67890_warm" <> ToString[n]];

(* from src/compare_q10_warm_vs_prod.wl:54-109 at bd355d2 *)
cmpWarm[p_, q_, t_, nW_] := Module[{is, prod, warm, isBars, prodBars, warmBars,
    keys, isV, pV, wV, l1IsP, l1IsW, l1PW, prodIter, warmIter, row, stored},
  is   = goldenImport[cmpName[p, q, "is_" <> t <> "_numv_hist"]];
  prod = goldenImport[cmpName[p, q, "mh_" <> t]];
  warm = goldenImport[warmName[p, q, t, nW]];
  isBars   = is["fracHist"];
  prodBars = gcBinMh[prod];
  warmBars = gcBinMh[warm];
  keys = Sort @ Union[Keys[isBars], Keys[prodBars], Keys[warmBars]];
  isV  = Lookup[isBars,   #, 0.] & /@ keys;
  pV   = Lookup[prodBars, #, 0.] & /@ keys;
  wV   = Lookup[warmBars, #, 0.] & /@ keys;
  l1IsP = gcL1[isBars, prodBars];
  l1IsW = gcL1[isBars, warmBars];
  l1PW  = gcL1[prodBars, warmBars];
  prodIter = prod["numIter"]; warmIter = warm["numIter"];
  row = <|"p" -> p, "q" -> q, "target" -> t,
    "warmInitNumV" -> nW,
    "isESS" -> is["ESS"],
    "prodIter" -> prodIter, "prodAcc" -> prod["acceptRate"],
    "warmIter" -> warmIter, "warmAcc" -> warm["acceptRate"],
    "l1IsProd" -> l1IsP, "l1IsWarm" -> l1IsW,
    "l1ProdWarm" -> l1PW|>;
  stored = gcStoredRow[goldenImport["q10_warm_vs_prod_summary.wxf"],
    <|"p" -> p, "q" -> q, "target" -> t|>];
  gcWithStoredMatch[
    Join[row, <|"keys" -> keys, "is" -> isV, "prod" -> pV, "warm" -> wV|>],
    row, stored]];

(* from src/render_q10_warm_vs_prod.wl:62-107 at bd355d2 (panel[p, q, t, nW]) *)
panelWarm[p_, q_, t_, nW_] := Module[{is, prod, warm, isBars, prodBars, warmBars,
    keys, isV, pV, wV, l1PW, l1IsP, l1IsW, lo, hi, isPts},
  is   = goldenImport[cmpName[p, q, "is_" <> t <> "_numv_hist"]];
  prod = goldenImport[cmpName[p, q, "mh_" <> t]];
  warm = goldenImport[warmName[p, q, t, nW]];
  isBars   = is["fracHist"];
  prodBars = gcBinMh[prod];
  warmBars = gcBinMh[warm];
  keys = Sort @ Union[Keys[isBars], Keys[prodBars], Keys[warmBars]];
  isV  = Lookup[isBars,   #, 0.] & /@ keys;
  pV   = Lookup[prodBars, #, 0.] & /@ keys;
  wV   = Lookup[warmBars, #, 0.] & /@ keys;
  l1IsP = gcL1[isBars, prodBars];
  l1IsW = gcL1[isBars, warmBars];
  l1PW  = gcL1[prodBars, warmBars];
  lo = First[keys]; hi = Last[keys];
  isPts = Pick[Transpose[{keys, isV}], # > 0 & /@ isV];
  gcWithHash[<|"figure" -> "is_vs_mh/q10_warm_vs_prod",
    "keys" -> keys, "bins" -> {lo - 0.5, hi + 0.5, 1},
    "bars" -> <|"MHprod" -> pV, "MHwarm" -> wV|>, "points" -> isPts,
    "label" -> <|"l1ProdWarm" -> l1PW, "l1IsProd" -> l1IsP,
      "l1IsWarm" -> l1IsW|>|>]];

(* ----- section ----- *)

goldenSection["compare"] := Module[{targets = {"vertex", "unlabeled", "facet"},
    cells3 = {{3, 5}, {4, 5}}, ps = {2, 3, 4}, inputs, records},
  inputs = Join[
    {"is_mh_truth_3way_summary.wxf", "q10_is_vs_mh_summary.wxf",
     "q10_warm_vs_prod_summary.wxf"},
    Flatten @ Table[{cmpName[c[[1]], c[[2]], "truth"],
        cmpName[c[[1]], c[[2]], "is_" <> t <> "_numv_hist"],
        cmpName[c[[1]], c[[2]], "mh_" <> t]}, {c, cells3}, {t, targets}],
    Flatten @ Table[{cmpName[p, 10, "is_" <> t <> "_numv_hist"],
        cmpName[p, 10, "mh_" <> t]}, {p, ps}, {t, targets}],
    warmName @@@ warmCells];
  records = Join[
    Association @ Flatten @ Table[
      "3way|p" <> ToString[c[[1]]] <> "q" <> ToString[c[[2]]] <> "|" <> t ->
        cmp3way[c[[1]], c[[2]], t], {c, cells3}, {t, targets}],
    Association @ Flatten @ Table[
      "render3way|p" <> ToString[c[[1]]] <> "q" <> ToString[c[[2]]] <> "|" <> t ->
        panel3way[c[[1]], c[[2]], t], {c, cells3}, {t, targets}],
    Association @ Flatten @ Table[
      "q10|p" <> ToString[p] <> "|" <> t -> cmpQ10[p, t], {p, ps}, {t, targets}],
    Association @ Flatten @ Table[
      "q10grid|p" <> ToString[p] <> "|" <> t ->
        panelQ10["is_vs_mh/q10_is_vs_mh_grid", p, t], {p, ps}, {t, targets}],
    (* from src/render_q10_is_vs_mh.wl:103 at bd355d2 (q10_p4_focus.png) *)
    Association @ Table[
      "q10focus|p4|" <> t -> panelQ10["is_vs_mh/q10_p4_focus", 4, t],
      {t, {"unlabeled", "facet"}}],
    Association @ Table[
      "warm|p" <> ToString[c[[1]]] <> "q10|" <> c[[3]] -> cmpWarm @@ c,
      {c, warmCells}],
    Association @ Table[
      "renderwarm|p" <> ToString[c[[1]]] <> "q10|" <> c[[3]] -> panelWarm @@ c,
      {c, warmCells}]];
  <|"inputs" -> inputs, "records" -> records|>];
