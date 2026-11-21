(* tests/golden/lib/overlay.wl
   Helpers for the "overlay" golden section: the binned data behind every
   panel of src/render_truth_overlay.wl, computed without rendering or
   exporting anything.

   extractPanelData and the per-mode bin specs are verbatim copies of
   render_truth_overlay.wl at bd355d2; only the loaders read through
   goldenImport instead of Import, and the per-bin aggregation replaces the
   Histogram call (Histogram's own sums are not exposed and differ from an
   explicit Total by up to ~2e-16). For the continuous panel (fig10,
   Automatic bins) the same Histogram call is built to read the bin edges
   it chose; nothing is exported. *)

(* ===== Grid and figure table ===== *)

(* from src/render_truth_overlay.wl:40-43 at bd355d2 *)
ovlReachableCells = {{2, 4}, {2, 5}, {2, 6}, {2, 7},
                     {3, 4}, {3, 5}, {3, 6},
                     {4, 4}, {4, 5}};
ovlAllTargets = {"unlabeled", "facet", "vertex"};

(* from src/render_truth_overlay.wl:253-264 at bd355d2
   {stackedStem, statColumn, xLabel, panelType, pSubset, filterSpec, manStem};
   xLabel is dropped (labels only). *)
ovlFigs = {
  {"fig03_numVertices",      "numV",             "discrete",    Automatic, None,        "NumVertices"},
  {"fig04_autOrder",         "aut",              "logdiscrete", Automatic, None,        "AutGorder"},
  {"fig05_autFOrder",        "autF",             "logdiscrete", Automatic, None,        "facetAutGorder"},
  {"fig06_autConnected",     "aut",              "logdiscrete", Automatic, "connected", "AutGorder"},
  {"fig07_autFConnected",    "autF",             "logdiscrete", Automatic, "connected", "facetAutGorder"},
  {"fig08_num1VConnComps",   "num1VConnComps",   "discrete",    Automatic, None,        "num1VConnectedComponents"},
  {"fig09_num2VConnComps",   "num2VConnComps",   "discrete",    Automatic, None,        "num2VConnectedComponents"},
  {"fig10_largestCompRatio", "largestCompRatio", "continuous",  Automatic, None,        "ratioOflargestCompVsVertexCount"},
  {"fig11_num2PathConnComps","num2PathConnComps","discrete",    {3, 4},    None,        "num2PConnectedComponents"},
  {"fig13_Betti1",           "Betti1",           "discrete",    Automatic, None,        "Betti1"},
  {"fig14_Betti2",           "Betti2",           "discrete",    {3, 4},    None,        "Betti2"}};

(* from src/render_truth_overlay.wl:267-270 at bd355d2 *)
ovlQsForP[p_] := Cases[ovlReachableCells, {p, q_} :> q];
ovlCellsForFig[pSubset_] := Module[{ps},
  ps = If[pSubset === Automatic, {2, 3, 4}, pSubset];
  Flatten[Table[{p, q}, {p, ps}, {q, ovlQsForP[p]}], 1]];

(* Stale pre-fix vertex MH chains still in the store (see AGENTS.md and
   docs: acceptRate 1, numV L1 vs truth 0.68-0.85). *)
ovlKnownBadVertex = {{2, 4}, {2, 5}, {2, 6}, {3, 4}, {3, 5}};

(* Fixed seed for the fig10 Automatic-bin Histogram (see ovlPanelRecord). *)
ovlHistSeed = 1;

(* ===== Loaders (render_truth_overlay.wl:81-95, through goldenImport) ===== *)
ovlTruthName[p_, q_] := "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth.wxf";
ovlMHName[p_, q_, target_] := "p" <> ToString[p] <> "q" <> ToString[q] <>
  "_mh_" <> target <> ".wxf";
ovlStoreHas[name_] := FileExistsQ[FileNameJoin[{$CombDataDir, name}]];
ovlLoadTruth[p_, q_] := If[ovlStoreHas[ovlTruthName[p, q]],
  goldenImport[ovlTruthName[p, q]], $Failed];
ovlLoadMH[p_, q_, target_] := If[ovlStoreHas[ovlMHName[p, q, target]],
  goldenImport[ovlMHName[p, q, target]], $Failed];

(* ===== Per-panel data extraction ===== *)
(* from src/render_truth_overlay.wl:101-153 at bd355d2 *)
ovlExtractPanelData[p_, q_, statName_String, target_String, filterSpec_] :=
  Module[{truth, mh, complexes, mass, statRaw, connRaw,
          mask, truthVals, truthMass, mhVals, mhRows, mhConn,
          mhStatCol, mhConnCol, headers},
  truth = ovlLoadTruth[p, q];
  mh    = ovlLoadMH[p, q, target];

  (* ----- Truth side ----- *)
  If[truth =!= $Failed,
    complexes = truth["complexes"];
    mass = truth[Switch[target,
      "vertex",    "piVertex",
      "facet",     "piFacet",
      "unlabeled", "piUnlabeled",
      _, Print["unknown target: ", target]; Abort[]]];
    statRaw = (#["stats"][statName]) & /@ complexes;
    connRaw = (#["stats"]["connected"]) & /@ complexes;
    mask = MapThread[
      Function[{s, c},
        NumericQ[s] && (filterSpec === None || c === 1)],
      {statRaw, connRaw}];
    truthVals = Pick[statRaw, mask];
    truthMass = Pick[mass, mask];
    If[Length[truthVals] > 0,
      truthMass = N[truthMass / Total[truthMass]],
      truthMass = {}],
   (* else *)
    truthVals = $Failed;
    truthMass = $Failed];

  (* ----- MH side ----- *)
  If[mh =!= $Failed,
    headers = mh["headers"];
    mhRows  = mh["rows"];
    mhStatCol = Position[headers, statName];
    If[mhStatCol === {},
      mhVals = $Failed,
      mhStatCol = mhStatCol[[1, 1]];
      mhConnCol = Position[headers, "connected"][[1, 1]];
      mhConn = mhRows[[All, mhConnCol]];
      mhVals = mhRows[[All, mhStatCol]];
      mask = MapThread[
        Function[{s, c},
          NumericQ[s] && (filterSpec === None || c === 1)],
        {mhVals, mhConn}];
      mhVals = Pick[mhVals, mask]],
   (* else *)
    mhVals = $Failed];

  <|"truthVals" -> truthVals, "truthMass" -> truthMass,
    "mhVals"    -> mhVals|>];

(* ===== Binning helpers ===== *)

(* Truth mass per bin: the renormalised weights summed per bin in file
   order, keys sorted. *)
ovlBinMass[keys_List, w_List] :=
  KeySort[GroupBy[Thread[keys -> w], First -> Last, Total]];
ovlBinCounts[keys_List] := KeySort[Counts[keys]];

(* Histogram with an explicit {lo, hi, dx} drops values at x >= hi (and
   x < lo) and renormalises "PDF" over the kept data; list such bins so a
   change in that edge case is visible. *)
ovlOutOfRange[bins_List, lo_, hi_] := Select[bins, # < lo || # >= hi &];

(* Bin edges Histogram drew, from its Rectangles, as integers in units of
   1e-12 (Rational keys do not survive a WXF round trip as ===). *)
ovlRectEdges[g_] := Union[Cases[g /. Legended[x_, ___] :> x,
  Rectangle[{x0_, _}, {x1_, _}, ___] :> Round[10^12 {x0, x1}], Infinity]];

(* from src/render_truth_overlay.wl:46-59 at bd355d2 (styles affect only
   the look; kept so the Histogram call matches the script's) *)
ovlColorTruth = RGBColor[0.122, 0.471, 0.706];
ovlColorMH    = RGBColor[0.890, 0.290, 0.200];
ovlTruthDirective = Directive[ovlColorTruth, Opacity[0.85],
  EdgeForm[Directive[ovlColorTruth, AbsoluteThickness[0.6]]]];
ovlMHDirective    = Directive[ovlColorMH, Opacity[0.55],
  EdgeForm[Directive[ovlColorMH, AbsoluteThickness[0.4]]]];

(* ===== One panel record ===== *)
(* Bin specs from render_truth_overlay.wl:167-179 (discrete),
   194-209 (logdiscrete), 224-231 (continuous) at bd355d2. *)
ovlPanelRecord[{stem_, statName_, panelType_, pSubset_, filterSpec_, manStem_},
    {p_, q_}, target_] :=
  Module[{d, tv, tm, mv, hasT, hasM, allKeys, lo, hi, lv, mvLog, spec,
          tBins, mBins, rec, series, g},
  d = ovlExtractPanelData[p, q, statName, target, filterSpec];
  tv = d["truthVals"]; tm = d["truthMass"]; mv = d["mhVals"];
  hasT = (tv =!= $Failed) && Length[tv] > 0;
  hasM = (mv =!= $Failed) && Length[mv] > 0;
  rec = <|"fig" -> stem, "stat" -> statName, "filter" -> filterSpec,
    "cell" -> {p, q}, "target" -> target, "mode" -> panelType,
    "hasTruth" -> hasT, "hasMH" -> hasM|>;
  If[!hasT && !hasM, Return[Append[rec, "binSpec" -> "emptyPanel"]]];
  Switch[panelType,
    "discrete",
      allKeys = Union[If[hasT, tv, {}], If[hasM, mv, {}]];
      lo = Floor[Min[allKeys]]; hi = Ceiling[Max[allKeys]];
      If[hi <= lo, hi = lo + 1];
      spec = {lo - 0.5, hi + 0.5, 1};
      (* bin [k - 0.5, k + 0.5) has key k *)
      tBins = If[hasT, Floor[tv + 1/2], {}];
      mBins = If[hasM, Floor[mv + 1/2], {}],
    "logdiscrete",
      lv    = If[hasT, Log10[N[tv]], {}];
      mvLog = If[hasM, Log10[N[mv]], {}];
      allKeys = Join[lv, mvLog];
      lo = Floor[Min[allKeys]]; hi = Ceiling[Max[allKeys]];
      If[hi <= lo, hi = lo + 1];
      spec = {lo, hi, 1};
      tBins = Floor[lv]; mBins = Floor[mvLog],
    "continuous",
      spec = Automatic;
      tBins = If[hasT, Round[10^6 N[tv]], {}];
      mBins = If[hasM, Round[10^6 N[mv]], {}];
      series = {
        If[hasT, WeightedData[N[tv], tm], Nothing],
        If[hasM, WeightedData[N[mv], ConstantArray[1./Length[mv], Length[mv]]],
          Nothing]};
      (* Histogram's Automatic bin choice draws on the global random state
         (probe 2026-11-20: same data, SeedRandom[4] gives width 0.1, seeds
         1,2,3,5 give 0.05; unseeded runs vary across processes), so the
         script's fig10 bins are not reproducible. Pin it here with a fixed
         seed; "histEdgesSeed" records it. *)
      g = BlockRandom[SeedRandom[ovlHistSeed];
        Histogram[series, Automatic, "PDF",
          ChartStyle -> {If[hasT, ovlTruthDirective, Nothing],
                         If[hasM, ovlMHDirective, Nothing]},
          Frame -> True, PlotRange -> All, ImageSize -> {360, 270}]]];
  rec = Join[rec, <|
    "binSpec" -> spec,
    "truthMass" -> If[hasT, ovlBinMass[tBins, tm], <||>],
    "truthClasses" -> If[hasT, Length[tv], 0],
    "mhCounts" -> If[hasM, ovlBinCounts[mBins], <||>],
    "mhN" -> If[hasM, Length[mv], 0]|>];
  If[panelType === "continuous",
    rec["histEdges"] = ovlRectEdges[g];
    rec["histEdgesSeed"] = ovlHistSeed,
    (* discrete keys run lo..hi, logdiscrete keys lo..hi-1 *)
    rec["outOfRangeBins"] = ovlOutOfRange[Union[tBins, mBins], lo,
      If[panelType === "discrete", hi + 1, hi]]];
  If[target === "vertex" && hasM && MemberQ[ovlKnownBadVertex, {p, q}],
    rec["knownBad"] = "stale pre-fix vertex MH chain " <> ovlMHName[p, q, target] <>
      " (acceptRate 1, made before the 2026-05-15 vertex fix)"];
  rec];

ovlRecordKey[stem_, {p_, q_}, target_] :=
  stem <> "|p" <> ToString[p] <> "q" <> ToString[q] <> "|" <> target;

(* All panels in the script's loop order (render_truth_overlay.wl:291-325:
   target outer, fig inner, cells within fig). *)
ovlAllPanels[] := Flatten[Table[
  {f, cell, target}, {target, ovlAllTargets}, {f, ovlFigs},
  {cell, ovlCellsForFig[f[[4]]]}], 2];
