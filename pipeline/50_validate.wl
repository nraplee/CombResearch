(* pipeline/50_validate.wl
   The validate stage (Phase 4 row 6): every comparison of sampled against
   exact (or reference) distributions, one job per process. run.wl validate
   runs each job with COMB_VAL_JOB set. Run by hand with the job as a plain
   word:

     wolframscript -file pipeline\50_validate.wl samples     (COMB_VAL_SOURCE)
     wolframscript -file pipeline\50_validate.wl results

   Jobs (the old script each one was; that script is now a shim that sets
   the job and Gets this file):
     counts            ECGrav's exact counters vs truth, per vertex count
                       (src/validate_counts_vs_truth.wl). Writes
                       results/counts_vs_truth.csv.
     samples           numV L1 and diagnostics of one sample source vs truth
                       (src/validate_mh_vs_truth.wl) ->
                       data/validation_{source}_summary.wxf
     efficiency        ESS / cost / accuracy of every sampler
                       (src/compare_samplers_efficiency.wl) ->
                       data/sampler_efficiency_summary.wxf
     3way              IS, MH and truth at the q=5 cells (src/compare_3way.wl)
                       -> data/is_mh_truth_3way_summary.wxf
     q10_is_vs_mh      IS vs MH at q=10 (src/compare_is_mh_q10.wl) ->
                       data/q10_is_vs_mh_summary.wxf
     q10_warm_vs_prod  warm-start vs production MH at q=10
                       (src/compare_q10_warm_vs_prod.wl) ->
                       data/q10_warm_vs_prod_summary.wxf
     results           every summary above that exists, as a flat table:
                       results/<summary name>.csv (validation_mh.csv,
                       sampler_efficiency.csv, ...). One row per result;
                       nested fields become name_field columns. Cheap;
                       run.wl runs it last on every validate.

   Each job's knobs keep their names (the COMB_VAL, COMB_EFF, COMB_3W and
   COMB_CMP knobs; see the job's section below). The distances and tests are the
   package's Compare.wl; the arithmetic is the old scripts', so the
   summaries reproduce the stored ones. *)

$pipelineDir = DirectoryName[$InputFileName];
$srcDir = FileNameJoin[{ParentDirectory[$pipelineDir], "src"}];
Get[FileNameJoin[{$srcDir, "comb_paths.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_names.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_io.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_config.wl"}]];
Get[FileNameJoin[{$srcDir, "load_combresearch.wl"}]];
dataDir = $CombDataDir;

$validateJobs = {"counts", "samples", "efficiency", "3way", "q10_is_vs_mh",
  "q10_warm_vs_prod", "results"};
valJobName = Which[
  StringQ[$CombValidateJob], $CombValidateJob,
  ListQ[$ScriptCommandLine] && Length[$ScriptCommandLine] > 1 &&
    MemberQ[$validateJobs, $ScriptCommandLine[[2]]], $ScriptCommandLine[[2]],
  True, combSetting["COMB_VAL_JOB", None]];
If[!MemberQ[$validateJobs, valJobName],
  Print["50_validate: name a job: ", StringRiffle[$validateJobs, ", "],
    " (plain word or COMB_VAL_JOB); got ", valJobName];
  Exit[2]];
Print["50_validate job = ", valJobName];

piKey = <|"vertex" -> "piVertex", "facet" -> "piFacet",
          "unlabeled" -> "piUnlabeled"|>;
defaultCells9 = {{2, 4}, {2, 5}, {2, 6}, {2, 7},
                 {3, 4}, {3, 5}, {3, 6},
                 {4, 4}, {4, 5}};

(* ======================================================================
   counts: ECGrav's exact counters vs our enumerated truth, per (p, q) cell
   and per vertex count n. All comparisons are exact integers.

     NumUnlabeledPureComplexes[p,q,n]     vs  #{iso classes X : nV(X) = n}
     NumFacetLabeledPureComplexes[p,q,n]  vs  Σ_{nV(X)=n} q!/autF(X)
     NumVertexLabeledPureComplexes[p,q,n] vs  Σ_{nV(X)=n} n!/aut(X)

   These are the normalizers of π_U, π_F, π_V, so a match here means ECGrav
   and we agree on what each ensemble IS before any sampler is tested. A
   mismatch in the facet column would point at a definitional difference in
   autF. Also prints the q=10 totals (no truth there) for reference.
   Knob: COMB_VAL_CELLS.
   ====================================================================== *)
valJob["counts"] := Module[{},
  resolvedCells = combSetting["COMB_VAL_CELLS", defaultCells9, "cells"];

  truthFile[p_, q_] := combFile["truth", p, q];

  (* Per-n exact counts from a truth payload. *)
  truthCountsByN[truth_Association] := Module[{q = truth["q"], cs},
    cs = truth["complexes"];
    GroupBy[cs, #["nV"] &,
      <|"U" -> Length[#],
        "F" -> Total[(q! / #["autF"]) & /@ #],
        "V" -> Total[(#["nV"]! / #["aut"]) & /@ #]|> &]];

  missingInputs = {};

  checkCell[p_, q_] := Module[{tf, truth, byN, ns, rows, allOK},
    tf = truthFile[p, q];
    If[!FileExistsQ[tf],
      Print["  *** skip: no truth at ", FileNameTake[tf], " ***"];
      AppendTo[missingInputs, tf];
      Return[$Failed]];
    truth = Import[tf, "WXF"];
    byN = truthCountsByN[truth];
    ns = Range[p, p q];
    rows = Table[
      With[{t = Lookup[byN, n, <|"U" -> 0, "F" -> 0, "V" -> 0|>],
            e = <|"U" -> NumUnlabeledPureComplexes[p, q, n],
                  "F" -> NumFacetLabeledPureComplexes[p, q, n],
                  "V" -> NumVertexLabeledPureComplexes[p, q, n]|>},
        <|"n" -> n, "truth" -> t, "ecg" -> e,
          "ok" -> AllTrue[{"U", "F", "V"}, t[#] === e[#] &]|>],
      {n, ns}];
    rows = Select[rows, #["truth"]["U"] > 0 || #["ecg"]["U"] > 0 &];
    Print["  ", StringPadRight["n", 5],
      StringPadRight["U truth/ecg", 22],
      StringPadRight["F truth/ecg", 34],
      StringPadRight["V truth/ecg", 40], "ok"];
    Do[
      Print["  ", StringPadRight[ToString[r["n"]], 5],
        StringPadRight[ToString[r["truth"]["U"]] <> "/" <>
          ToString[r["ecg"]["U"]], 22],
        StringPadRight[ToString[r["truth"]["F"]] <> "/" <>
          ToString[r["ecg"]["F"]], 34],
        StringPadRight[ToString[r["truth"]["V"]] <> "/" <>
          ToString[r["ecg"]["V"]], 40],
        If[r["ok"], "ok", "*** MISMATCH ***"]],
      {r, rows}];
    allOK = AllTrue[rows, #["ok"] &];
    <|"p" -> p, "q" -> q, "ok" -> allOK,
      "isoTruth" -> truth["numIsoClasses"],
      "isoECGrav" -> NumUnlabeledPureComplexes[p, q],
      "perN" -> rows|>];

  results = {};
  Do[
    Print["========================================"];
    Print["cell (", cell[[1]], ", ", cell[[2]], ")"];
    With[{r = checkCell @@ cell},
      If[AssociationQ[r], AppendTo[results, r]]],
    {cell, resolvedCells}];

  Print["========================================"];
  Print["SUMMARY  (ECGrav ", $CombECGravVersion, ")"];
  Print["========================================"];
  Do[
    Print["  (", r["p"], ",", r["q"], ")  iso truth = ", r["isoTruth"],
      "  ECGrav = ", r["isoECGrav"], "   per-n U/F/V: ",
      If[r["ok"], "ALL MATCH", "*** MISMATCH ***"]],
    {r, results}];
  Print["Total: ", Length[results], "  Mismatches: ",
    Count[results, r_ /; !r["ok"]]];
  If[missingInputs =!= {},
    Print["*** ", Length[missingInputs], " cell(s) NOT CHECKED: missing in ", dataDir, ":"];
    Scan[Print["      ", FileNameTake[#]] &, missingInputs];
    Print["    Generate with: wolframscript -file run.wl truth cells \"p,q;...\""]];

  (* one row per cell and vertex count *)
  If[results =!= {},
    exportCsvAtomic[combFile["results", "counts_vs_truth"],
      Prepend[
        Flatten[Table[{r["p"], r["q"], n["n"], n["truth"]["U"], n["ecg"]["U"],
            n["truth"]["F"], n["ecg"]["F"], n["truth"]["V"], n["ecg"]["V"],
            ToString[n["ok"]]},
          {r, results}, {n, r["perN"]}], 1],
        {"p", "q", "n", "unlabeledTruth", "unlabeledECGrav", "facetTruth",
          "facetECGrav", "vertexTruth", "vertexECGrav", "ok"}],
      <|"inputs" -> (FileNameTake[truthFile[#["p"], #["q"]]] & /@ results)|>];
    Print["wrote ", combFile["results", "counts_vs_truth"]]];

  Print[""];
  Print["q=10 totals (no truth; reference only):"];
  Do[
    Print["  p=", p, "  U=", NumUnlabeledPureComplexes[p, 10],
      "  F=", NumFacetLabeledPureComplexes[p, 10],
      "  V=", NumVertexLabeledPureComplexes[p, 10]],
    {p, {2, 3, 4}}]];

(* ======================================================================
   samples: per (p, q) × target, the sampled numV histogram vs the exact
   π_target marginal on numV from the truth WXF: per-bin probabilities, L1
   distance, an ASCII overlay.

   Knobs: COMB_VAL_CELLS, COMB_VAL_TARGETS, COMB_VAL_THRESHOLD (default
   0.05), COMB_VAL_SOURCE:
     mh               data/p{p}q{q}_mh_{target}.wxf   (default)
     ecgexact         data/p{p}q{q}_ecgexact_{target}.wxf
     ecgmcmc          data/p{p}q{q}_ecgmcmc_{target}.wxf
     ecglegacyfacet   negative control (must FAIL)

   Extra diagnostics beyond the numV L1:
     - iid p-value of the observed numV L1 (IIDL1PValue). Only meaningful
       for independent draws (ecgexact; roughly for ecgmcmc, whose draws
       are corrT sweeps apart). MH rows are autocorrelated, so a low value
       there is expected.
     - per-iso-class Pearson chi-square (IsoClassChiSquare), when the
       payload carries "classIdx" (ecg* sources), and the count of samples
       that matched no truth class (must be 0).
     - L1 of every other stat marginal; the worst one is reported.
   Writes data/validation_{source}_summary.wxf.
   ====================================================================== *)
valJob["samples"] := Module[{},
  defaultTargets = {"unlabeled", "facet", "vertex"};
  resolvedCells = combSetting["COMB_VAL_CELLS", defaultCells9, "cells"];
  resolvedTargets = combSetting["COMB_VAL_TARGETS", defaultTargets, "list"];
  threshold = combSetting["COMB_VAL_THRESHOLD", 0.05, "expr"];
  source = combSetting["COMB_VAL_SOURCE", "mh"];

  Print["dataDir          = ", dataDir];
  Print["resolvedCells    = ", resolvedCells];
  Print["resolvedTargets  = ", resolvedTargets];
  Print["L1 threshold     = ", threshold];
  Print["source           = ", source];
  Print[""];

  truthFile[p_, q_] := combFile["truth", p, q];
  mhFile[p_, q_, t_] := combFile["samples", p, q, source, t];

  (* Align two Associations on the union of keys and compute |a-b| per
     bin, plus total L1 (= HistogramL1Distance). *)
  compareBins[truthBars_Association, mhBars_Association] := Module[
    {keys, tv, mv, diffs, l1},
    keys = Sort @ Union[Keys[truthBars], Keys[mhBars]];
    tv = Lookup[truthBars, #, 0.] & /@ keys;
    mv = Lookup[mhBars,    #, 0.] & /@ keys;
    diffs = Abs[tv - mv];
    l1 = Total[diffs];
    <|"keys" -> keys, "truth" -> tv, "mh" -> mv, "diff" -> diffs,
      "l1" -> l1|>];

  (* ASCII bar at scale = 40 chars per unit probability. *)
  asciiBar[p_, scale_:40] := StringJoin @ ConstantArray["#", Round[p * scale]];

  printOverlay[label_String, cmp_Association, l1Pass_] := Module[
    {keys, truth, mh, diffs},
    keys = cmp["keys"]; truth = cmp["truth"]; mh = cmp["mh"]; diffs = cmp["diff"];
    Print["  ", label,
      "  L1 = ", NumberForm[cmp["l1"], {6, 4}],
      "   ", If[l1Pass, "PASS (<", "FAIL (≥"], threshold, ")"];
    Print["    ",
      StringPadRight["numV", 6],
      StringPadRight["truth", 12],
      StringPadRight["mh", 12],
      "diff       overlay (T=., M=#)"];
    MapThread[
      Function[{k, t, m, d},
        Print["    ",
          StringPadRight[ToString[k], 6],
          StringPadRight[ToString[NumberForm[t, {6, 4}]], 12],
          StringPadRight[ToString[NumberForm[m, {6, 4}]], 12],
          StringPadRight[ToString[NumberForm[d, {5, 4}]], 11],
          StringPadRight[asciiBar[t, 30], 30, "."],
          " | ", asciiBar[m, 30]]],
      {keys, truth, mh, diffs}]];

  (* L1 between the truth marginal and the sample marginal of stat column j.
     Values rounded so float stats (largestCompRatio) bin identically. *)
  statKey[v_?NumericQ] := Round[v, 10^-6];
  statKey[v_] := v;
  statMarginalL1[truth_Association, target_String, rows_List, j_Integer,
                 name_String] := Module[{pi, tv, sv, tb, sb},
    pi = truth[piKey[target]];
    tv = statKey[#["stats"][name]] & /@ truth["complexes"];
    tb = Merge[Thread[tv -> pi], Total];
    sv = statKey /@ rows[[All, j]];
    sb = N[Counts[sv] / Length[sv]];
    compareBins[tb, sb]["l1"]];

  missingInputs = {};

  validateCell[p_, q_, target_String] := Module[
    {tFile, mFile, truth, mh, truthBars, mhBars, cmp, l1Pass,
     nRows, iidP, cls = Missing["NoClassIdx"], unmatched = Missing[],
     otherL1, worst},
    tFile = truthFile[p, q];
    mFile = mhFile[p, q, target];
    If[!FileExistsQ[tFile],
      Print["  *** skip: no truth WXF at ", FileNameTake[tFile], " ***"];
      AppendTo[missingInputs, tFile];
      Return[$Failed]];
    If[!FileExistsQ[mFile],
      Print["  *** skip: no MH WXF at ", FileNameTake[mFile], " ***"];
      AppendTo[missingInputs, mFile];
      Return[$Failed]];
    truth = Import[tFile, "WXF"];
    mh = Import[mFile, "WXF"];
    truthBars = PureComplexTruthMarginal[truth, target];
    mhBars    = SampleHistogram[mh["rows"][[All, 1]]];
    cmp = compareBins[truthBars, mhBars];
    l1Pass = cmp["l1"] < threshold;
    printOverlay["target=" <> target, cmp, l1Pass];
    nRows = Length[mh["rows"]];
    iidP = IIDL1PValue[truthBars, nRows, cmp["l1"]];
    Print["    N = ", nRows, "   iid p-value of numV L1 = ", iidP];
    If[ListQ[mh["classIdx"]],
      unmatched = Count[mh["classIdx"], 0];
      cls = IsoClassChiSquare[truth[piKey[target]], mh["classIdx"]];
      Print["    per-class chi2 = ", NumberForm[cls["chi2"], {8, 2}],
        "  df = ", cls["df"], "  p = ", NumberForm[cls["pValue"], {5, 4}],
        "   unmatched samples = ", unmatched]];
    otherL1 = Association @ Table[
      With[{name = mh["headers"][[j]]},
        If[MatchQ[truth["complexes"][[1]]["stats"][name], ""], Nothing,
          name -> statMarginalL1[truth, target, mh["rows"], j, name]]],
      {j, 2, Length[mh["headers"]]}];
    worst = First @ Keys @ TakeLargest[otherL1, 1];
    Print["    other stats: worst L1 = ", NumberForm[otherL1[worst], {6, 4}],
      " (", worst, ")"];
    <|"p" -> p, "q" -> q, "target" -> target, "source" -> source,
      "n" -> nRows, "l1" -> cmp["l1"], "pass" -> l1Pass,
      "iidPValue" -> iidP, "classChi2" -> cls, "unmatched" -> unmatched,
      "otherStatL1" -> otherL1|>];

  allResults = {};
  Do[
    Module[{p = cell[[1]], q = cell[[2]]},
      Print["========================================"];
      Print["cell (", p, ", ", q, ")"];
      Print["========================================"];
      Do[
        Module[{r},
          r = validateCell[p, q, target];
          If[AssociationQ[r], AppendTo[allResults, r]];
          Print[""]],
        {target, resolvedTargets}]],
    {cell, resolvedCells}];

  Print["========================================"];
  Print["SUMMARY"];
  Print["========================================"];
  Print["  ",
    StringPadRight["cell",      10],
    StringPadRight["target",    12],
    StringPadRight["L1",        10],
    StringPadRight["iid p",     8],
    StringPadRight["class p",   10],
    StringPadRight["worst other", 26],
    "verdict"];
  Do[
    Print["  ",
      StringPadRight["(" <> ToString[r["p"]] <> "," <>
                            ToString[r["q"]] <> ")", 10],
      StringPadRight[r["target"], 12],
      StringPadRight[ToString[NumberForm[r["l1"], {6, 4}]], 10],
      StringPadRight[ToString[NumberForm[r["iidPValue"], {4, 3}]], 8],
      StringPadRight[If[AssociationQ[r["classChi2"]],
        ToString[NumberForm[r["classChi2"]["pValue"], {4, 3}]], "-"], 10],
      StringPadRight[With[{w = First @ Keys @ TakeLargest[r["otherStatL1"], 1]},
        ToString[NumberForm[r["otherStatL1"][w], {5, 4}]] <> " " <> w], 26],
      If[r["pass"], "PASS", "*** FAIL ***"]],
    {r, allResults}];

  failCount = Count[allResults, r_ /; !r["pass"]];
  Print[""];
  Print["Total: ", Length[allResults], "  Failures: ", failCount];
  If[failCount > 0, Print["At least one cell×target exceeded L1 threshold ",
    threshold, ". Investigate."]];
  If[missingInputs =!= {},
    missingInputs = DeleteDuplicates[missingInputs];
    Print["*** ", Length[missingInputs], " input file(s) missing in ", dataDir,
      "; those cell x target combinations were NOT validated:"];
    Scan[Print["      ", FileNameTake[#]] &, missingInputs];
    Print["    Truth: wolframscript -file run.wl truth"];
    Print["    Samples: wolframscript -file run.wl mh (source mh) or run.wl ecgrav (sampler ...)"]];

  (* Nothing validated (all inputs missing): keep any existing summary. *)
  If[allResults =!= {},
    exportWxfAtomic[combFile["validationSummary", source],
      <|"source" -> source, "threshold" -> threshold, "results" -> allResults,
        "createdAt" -> DateString[]|>]]];

(* ======================================================================
   efficiency: ESS / cost / accuracy across every sampler, per (p, q) ×
   target, on the numV marginal.

   Sources (each included only if its WXF exists):
     mh            data/p{p}q{q}_mh_{target}.wxf           our MH chains
     ecgmcmc       data/p{p}q{q}_ecgmcmc_{target}.wxf      ECGrav RandomPureSimplicialComplexMCMC
     ecgexact      data/p{p}q{q}_ecgexact_{target}.wxf     ECGrav exact samplers
     is-ecgvertex  data/p{p}q{q}_ecgexact_vertex.wxf       IS reweighting of the
                                                           ECGrav vertex draws (unlabeled/facet)
     is-legacy     data/p{p}q10_merged_stats.wxf           the q=10 IS runs (q=10 only)

   ESS: mh, ecgmcmc, ecgexact: n / (2 τ_int) on the numV sequence
   (IntegratedAutocorrelationTime; for ecgexact ≈ N, the independence
   check). is-*: Kish. ecgmcmc also reports τ_int per sweep from its
   separate trace, and ECGrav's own corrT.

   Accuracy: numV L1 against the truth marginal when the truth WXF exists,
   otherwise against the ecgexact histogram (the q=10 reference), with a
   split-half L1 of ecgexact as that reference's noise floor.

   Wall seconds are sampling time only and machine- and load-dependent.
   Knobs: COMB_EFF_CELLS, COMB_EFF_TARGETS.
   Writes data/sampler_efficiency_summary.wxf.
   ====================================================================== *)
valJob["efficiency"] := Module[{},
  defaultCells = Join[defaultCells9, {{2, 10}, {3, 10}, {4, 10}}];
  defaultTargets = {"unlabeled", "facet", "vertex"};
  resolvedCells   = combSetting["COMB_EFF_CELLS", defaultCells, "cells"];
  resolvedTargets = combSetting["COMB_EFF_TARGETS", defaultTargets, "list"];

  loadIf[f_] := If[FileExistsQ[f], Import[f, "WXF"], Missing["NoFile"]];

  (* same arithmetic as the stored summary (Counts, Merge over the samples) *)
  unweightedHist[x_List] := N[Counts[x] / Length[x]];
  weightedHist[x_List, w_List] := Module[{m = Merge[Thread[x -> w], Total]},
    N[m / Total[w]]];

  truthMarginal[truth_, target_] := Merge[
    Thread[(#["nV"] & /@ truth["complexes"]) -> truth[piKey[target]]], Total];

  row[src_, n_, wall_, ess_, l1v_, extra_:<||>] := Join[<|
    "source" -> src, "n" -> n, "wall" -> wall, "ess" -> ess,
    "essFrac" -> If[NumericQ[ess] && n > 0, ess / n, Missing[]],
    "essPerSec" -> If[NumericQ[ess] && NumericQ[wall] && wall > 0,
      ess / wall, Missing[]],
    "l1" -> l1v|>, extra];

  chainRow[src_, payload_, ref_] := Module[{x, ac, extra = <||>},
    x = payload["rows"][[All, 1]];
    ac = IntegratedAutocorrelationTime[x];
    If[KeyExistsQ[payload, "traceNumV"],
      With[{act = IntegratedAutocorrelationTime[payload["traceNumV"]]},
        extra = <|"tauPerSweepTrace" -> act["tau"],
          "corrT" -> payload["corrT"], "eqlT" -> payload["eqlT"],
          "traceEssPerSec" -> If[payload["traceSeconds"] > 0,
            act["ess"] / payload["traceSeconds"], Missing[]]|>]];
    row[src, Length[x], payload["wallSeconds"], ac["ess"],
      If[AssociationQ[ref], HistogramL1Distance[unweightedHist[x], ref], Missing["NoRef"]],
      Join[<|"tau" -> ac["tau"]|>, extra]]];

  (* IS from vertex draws. rows: {numV, aut, autF, ...}. *)
  isWeights[rows_, q_, "unlabeled"] := MapThread[#2 / #1! &,
    {rows[[All, 1]], rows[[All, 2]]}];
  isWeights[rows_, q_, "facet"] := MapThread[#2 q! / (#3 #1!) &,
    {rows[[All, 1]], rows[[All, 2]], rows[[All, 3]]}];
  isRow[src_, rows_, q_, target_, wall_, ref_] := Module[{w},
    w = N @ isWeights[rows, q, target];
    row[src, Length[rows], wall, EffectiveSampleSize[w],
      If[AssociationQ[ref], HistogramL1Distance[weightedHist[rows[[All, 1]], w], ref],
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
          HistogramL1Distance[unweightedHist[halves[[1]]], unweightedHist[halves[[2]]]]]]];
    If[AssociationQ[vx] && target =!= "vertex",
      AppendTo[out, isRow["is-ecgvertex", vx["rows"], q, target,
        vx["wallSeconds"], ref]]];
    If[AssociationQ[legacy] && target =!= "vertex",
      (* legacy columns 14/15 are wUnlabeled/wFacet *)
      With[{w = N @ legacy["rows"][[All, If[target === "unlabeled", 14, 15]]],
            x = legacy["rows"][[All, 1]]},
        AppendTo[out, row["is-legacy", Length[x], Missing["Unrecorded"],
          EffectiveSampleSize[w], If[AssociationQ[ref], HistogramL1Distance[weightedHist[x, w], ref],
            Missing["NoRef"]]]]]];
    If[AssociationQ[legacy] && target === "vertex",
      With[{x = legacy["rows"][[All, 1]]},
        AppendTo[out, row["direct-legacy", Length[x], Missing["Unrecorded"],
          Length[x], If[AssociationQ[ref], HistogramL1Distance[unweightedHist[x], ref],
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

  exportWxfAtomic[combFile["summary", "sampler_efficiency"],
    <|"results" -> results, "ecGravVersion" -> $CombECGravVersion,
      "createdAt" -> DateString[]|>];
  Print[""];
  Print["wrote data/sampler_efficiency_summary.wxf"]];

(* ======================================================================
   3way: IS, MH and truth numV marginals at cells where all three exist
   (default (3,5) and (4,5)): an ASCII overlay and the pairwise L1s.
   Reads p{p}q{q}_truth.wxf, p{p}q{q}_mh_{target}.wxf,
   p{p}q{q}_is_{target}_numv_hist.wxf.
   Knobs: COMB_3W_CELLS (default "3,5;4,5"), COMB_3W_TARGETS.
   Writes data/is_mh_truth_3way_summary.wxf.
   ====================================================================== *)
valJob["3way"] := Module[{},
  cells = combSetting["COMB_3W_CELLS", {{3, 5}, {4, 5}}, "cells"];
  targets = combSetting["COMB_3W_TARGETS", {"vertex", "unlabeled", "facet"}, "list"];

  truthFile[p_, q_]    := combFile["truth", p, q];
  mhFile[p_, q_, t_]   := combFile["mh", p, q, t];
  isFile[p_, q_, t_]   := combFile["isHist", p, q, t];

  asciiBar[p_, scale_:25] :=
    StringJoin @ ConstantArray["#", Round[p * scale]];

  results = {};

  Do[
    Module[{p = cell[[1]], q = cell[[2]], truth},
      Print["================================================"];
      Print["cell (", p, ",", q, ")"];
      Print["================================================"];
      truth = Import[truthFile[p, q], "WXF"];
      Do[
        Module[{isData, mh, isBars, mhBars, tBars, keys, isV, mhV, tV,
                l1IsT, l1MhT, l1IsMh, ess, niter, acc},
          isData = Import[isFile[p, q, t], "WXF"];
          mh     = Import[mhFile[p, q, t], "WXF"];
          isBars = isData["fracHist"];
          mhBars = SampleHistogram[mh["rows"][[All, 1]]];
          tBars  = PureComplexTruthMarginal[truth, t];

          keys = Sort @ Union[Keys[isBars], Keys[mhBars], Keys[tBars]];
          isV  = Lookup[isBars, #, 0.] & /@ keys;
          mhV  = Lookup[mhBars, #, 0.] & /@ keys;
          tV   = N @ Lookup[tBars,  #, 0.] & /@ keys;

          l1IsT  = HistogramL1Distance[isBars, tBars];
          l1MhT  = HistogramL1Distance[mhBars, tBars];
          l1IsMh = HistogramL1Distance[isBars, mhBars];
          ess   = isData["ESS"];
          niter = mh["numIter"];
          acc   = mh["acceptRate"];

          Print[""];
          Print["  target=", t,
            "   IS N=", isData["sourceN"], " ESS=", NumberForm[ess, 4],
            "   MH iters=", niter, " acc=", NumberForm[acc, {4, 3}]];
          Print["    L1(IS, truth) = ", NumberForm[l1IsT,  {6, 4}]];
          Print["    L1(MH, truth) = ", NumberForm[l1MhT,  {6, 4}]];
          Print["    L1(IS, MH)    = ", NumberForm[l1IsMh, {6, 4}]];
          Print[""];
          Print["    ",
            StringPadRight["numV",  6],
            StringPadRight["truth", 12],
            StringPadRight["IS",    12],
            StringPadRight["MH",    12],
            "T=., I=>, M=#"];
          MapThread[Function[{k, tv, iv, mv},
            Print["    ",
              StringPadRight[ToString[k], 6],
              StringPadRight[ToString[NumberForm[tv, {6, 4}]], 12],
              StringPadRight[ToString[NumberForm[iv, {6, 4}]], 12],
              StringPadRight[ToString[NumberForm[mv, {6, 4}]], 12],
              StringPadRight[asciiBar[tv, 25], 25, "."],
              " | ", StringPadRight[asciiBar[iv, 25], 25, " "],
              " | ", asciiBar[mv, 25]]],
            {keys, tV, isV, mhV}];

          AppendTo[results, <|"p" -> p, "q" -> q, "target" -> t,
            "l1IsTruth" -> l1IsT, "l1MhTruth" -> l1MhT,
            "l1IsMh"    -> l1IsMh,
            "isN" -> isData["sourceN"], "isESS" -> ess,
            "mhIter" -> niter, "mhAccept" -> acc|>]],
        {t, targets}]],
    {cell, cells}];

  Print[""];
  Print["================================================"];
  Print["SUMMARY"];
  Print["================================================"];
  Print["  ",
    StringPadRight["cell",         8],
    StringPadRight["target",      12],
    StringPadRight["IS N",        10],
    StringPadRight["IS ESS",      10],
    StringPadRight["L1(IS,T)",    11],
    StringPadRight["L1(MH,T)",    11],
    "L1(IS,MH)"];
  Do[
    Print["  ",
      StringPadRight["(" <> ToString[r["p"]] <> "," <>
                     ToString[r["q"]] <> ")", 8],
      StringPadRight[r["target"], 12],
      StringPadRight[ToString[r["isN"]], 10],
      StringPadRight[ToString[NumberForm[r["isESS"], 4]], 10],
      StringPadRight[ToString[NumberForm[r["l1IsTruth"], {5, 4}]], 11],
      StringPadRight[ToString[NumberForm[r["l1MhTruth"], {5, 4}]], 11],
      NumberForm[r["l1IsMh"], {5, 4}]],
    {r, results}];

  exportWxfAtomic[combFile["summary", "is_mh_truth_3way"],
    <|"results" -> results, "createdAt" -> DateString[]|>];
  Print[""];
  Print["wrote is_mh_truth_3way_summary.wxf"]];

(* ======================================================================
   q10_is_vs_mh: MH numV histograms vs IS-reweighted ones at q=10 for each
   p and target. No truth exists at q=10. Expected: p=2 close (IS ESS
   ~500-700); p=3 borderline (ESS ~100-120), bin diffs ~1/sqrt(ESS); p=4
   large disagreement on rare bins (IS ESS ~25, MH is the trusted side).
   Reads p{p}q10_is_{target}_numv_hist.wxf and p{p}q10_mh_{target}.wxf.
   Knobs: COMB_CMP_PS (default 2,3,4), COMB_CMP_TARGETS.
   Writes data/q10_is_vs_mh_summary.wxf.
   ====================================================================== *)
valJob["q10_is_vs_mh"] := Module[{},
  resolvedPs = combSetting["COMB_CMP_PS", {2, 3, 4}, "intList"];
  resolvedTargets = combSetting["COMB_CMP_TARGETS", {"vertex", "unlabeled", "facet"}, "list"];

  isFile[p_, t_] := combFile["isHist", p, 10, t];
  mhFile[p_, t_] := combFile["mh", p, 10, t];

  cmpBars[isBars_, mhBars_] := Module[{keys, iv, mv, diffs, l1},
    keys  = Sort @ Union[Keys[isBars], Keys[mhBars]];
    iv    = Lookup[isBars, #, 0.] & /@ keys;
    mv    = Lookup[mhBars, #, 0.] & /@ keys;
    diffs = Abs[iv - mv];
    l1    = Total[diffs];
    <|"keys" -> keys, "is" -> iv, "mh" -> mv, "diff" -> diffs,
      "l1" -> l1|>];

  asciiBar[p_, scale_:30] :=
    StringJoin @ ConstantArray["#", Round[p * scale]];

  printOverlay[label_String, cmp_] := Module[
    {keys, is, mh, diffs},
    keys = cmp["keys"]; is = cmp["is"]; mh = cmp["mh"]; diffs = cmp["diff"];
    Print["  ", label, "   L1 = ", NumberForm[cmp["l1"], {6, 4}]];
    Print["    ",
      StringPadRight["numV", 6],
      StringPadRight["IS", 12],
      StringPadRight["MH", 12],
      StringPadRight["|d|", 11],
      "overlay (IS=., MH=#)"];
    MapThread[
      Function[{k, i, m, d},
        Print["    ",
          StringPadRight[ToString[k], 6],
          StringPadRight[ToString[NumberForm[i, {6, 4}]], 12],
          StringPadRight[ToString[NumberForm[m, {6, 4}]], 12],
          StringPadRight[ToString[NumberForm[d, {5, 4}]], 11],
          StringPadRight[asciiBar[i, 25], 25, "."],
          " | ", asciiBar[m, 25]]],
      {keys, is, mh, diffs}]];

  allResults = {};

  Do[
    Module[{p = pp},
      Print["========================================"];
      Print["p = ", p, "  (N = ", p*10, ")"];
      Print["========================================"];
      Do[
        Module[{iFile, mFile, isData, mhData, isBars, mhBars, cmp, ess,
                acc, niter},
          iFile = isFile[p, target];
          mFile = mhFile[p, target];
          If[!FileExistsQ[iFile],
            Print["  *** skip: missing IS ", FileNameTake[iFile]];
            Continue[]];
          If[!FileExistsQ[mFile],
            Print["  *** skip: missing MH ", FileNameTake[mFile]];
            Continue[]];
          isData = Import[iFile, "WXF"];
          mhData = Import[mFile, "WXF"];
          isBars = isData["fracHist"];
          mhBars = SampleHistogram[mhData["rows"][[All, 1]]];
          cmp    = cmpBars[isBars, mhBars];
          ess    = isData["ESS"];
          acc    = mhData["acceptRate"];
          niter  = mhData["numIter"];
          printOverlay[
            "target=" <> target <>
            "   IS ESS=" <> ToString[NumberForm[ess, 4]] <>
            "   MH iters=" <> ToString[niter] <>
            "   acc=" <> ToString[NumberForm[acc, {4, 3}]],
            cmp];
          AppendTo[allResults, <|"p" -> p, "target" -> target,
            "l1" -> cmp["l1"], "isESS" -> ess, "mhIter" -> niter,
            "acceptRate" -> acc|>];
          Print[""]],
        {target, resolvedTargets}]],
    {pp, resolvedPs}];

  Print["========================================"];
  Print["SUMMARY  (q=10)"];
  Print["========================================"];
  Print["  ",
    StringPadRight["p", 4],
    StringPadRight["target",  12],
    StringPadRight["IS ESS",  12],
    StringPadRight["MH iters", 12],
    StringPadRight["MH acc",  10],
    "L1(IS, MH)"];
  Do[
    Print["  ",
      StringPadRight[ToString[r["p"]], 4],
      StringPadRight[r["target"], 12],
      StringPadRight[ToString[NumberForm[r["isESS"], 4]], 12],
      StringPadRight[ToString[r["mhIter"]], 12],
      StringPadRight[ToString[NumberForm[r["acceptRate"], {4, 3}]], 10],
      NumberForm[r["l1"], {6, 4}]],
    {r, allResults}];

  exportWxfAtomic[combFile["summary", "q10_is_vs_mh"],
    <|"results" -> allResults, "createdAt" -> DateString[]|>];
  Print[""];
  Print["wrote q10_is_vs_mh_summary.wxf"]];

(* ======================================================================
   q10_warm_vs_prod: the warm-start seed-67890 1M-iter MH chains vs the
   production seed-12345 200k-iter chains and vs the IS histogram, at the 4
   q=10 disagreement cells.
     L1(MH_warm, MH_prod) small -> both chains stationary in the same
       region -> IS broken.
     L1(MH_warm, MH_prod) large -> at least one is trapped.
   Reads p{p}q10_is_{target}_numv_hist.wxf, p{p}q10_mh_{target}.wxf,
   p{p}q10_mh_{target}_seed67890_warm{N}.wxf.
   Writes data/q10_warm_vs_prod_summary.wxf.
   ====================================================================== *)
valJob["q10_warm_vs_prod"] := Module[{},
  cells = {{3, 10, "unlabeled", 14}, {3, 10, "facet", 14},
           {4, 10, "unlabeled", 18}, {4, 10, "facet", 18}};

  isFile[p_, q_, t_]     := combFile["isHist", p, q, t];
  mhFile[p_, q_, t_]     := combFile["mh", p, q, t];
  warmFile[p_, q_, t_, n_] := combFile["mh", p, q, t, combMHWarmTag[67890, n]];

  asciiBar[p_, scale_:25] :=
    StringJoin @ ConstantArray["#", Round[p * scale]];

  results = {};

  Do[
    Module[{p = c[[1]], q = c[[2]], t = c[[3]], nW = c[[4]],
            is, prod, warm, isBars, prodBars, warmBars,
            keys, isV, pV, wV, l1IsP, l1IsW, l1PW, prodIter, warmIter},
      Print["================================================"];
      Print["cell (", p, ",", q, ")  target=", t, "  warm@numV=", nW];
      Print["================================================"];
      is   = Import[isFile[p, q, t], "WXF"];
      prod = Import[mhFile[p, q, t], "WXF"];
      warm = Import[warmFile[p, q, t, nW], "WXF"];
      isBars   = is["fracHist"];
      prodBars = SampleHistogram[prod["rows"][[All, 1]]];
      warmBars = SampleHistogram[warm["rows"][[All, 1]]];

      keys = Sort @ Union[Keys[isBars], Keys[prodBars], Keys[warmBars]];
      isV  = Lookup[isBars,   #, 0.] & /@ keys;
      pV   = Lookup[prodBars, #, 0.] & /@ keys;
      wV   = Lookup[warmBars, #, 0.] & /@ keys;
      l1IsP = HistogramL1Distance[isBars, prodBars];
      l1IsW = HistogramL1Distance[isBars, warmBars];
      l1PW  = HistogramL1Distance[prodBars, warmBars];

      prodIter = prod["numIter"]; warmIter = warm["numIter"];

      Print["  IS ESS = ", NumberForm[is["ESS"], 4]];
      Print["  prod (seed 12345, default init, ", prodIter, " iters)  acc=",
        NumberForm[prod["acceptRate"], {4, 3}]];
      Print["  warm (seed 67890, init@numV=", nW, ", ", warmIter, " iters)  acc=",
        NumberForm[warm["acceptRate"], {4, 3}]];
      Print["  L1(IS,   MH_prod) = ", NumberForm[l1IsP, {6, 4}]];
      Print["  L1(IS,   MH_warm) = ", NumberForm[l1IsW, {6, 4}]];
      Print["  L1(prod, warm)    = ", NumberForm[l1PW,  {6, 4}],
        "  <-- key disambiguator"];
      Print[""];
      Print["    ",
        StringPadRight["numV",  6],
        StringPadRight["IS",    12],
        StringPadRight["prod",  12],
        StringPadRight["warm",  12]];
      MapThread[Function[{k, iv, pv, wvv},
        Print["    ",
          StringPadRight[ToString[k], 6],
          StringPadRight[ToString[NumberForm[iv, {6, 4}]], 12],
          StringPadRight[ToString[NumberForm[pv, {6, 4}]], 12],
          StringPadRight[ToString[NumberForm[wvv, {6, 4}]], 12],
          StringPadRight[asciiBar[iv, 25], 25, " "],
          " | ", StringPadRight[asciiBar[pv, 25], 25, " "],
          " | ", asciiBar[wvv, 25]]],
        {keys, isV, pV, wV}];

      AppendTo[results, <|"p" -> p, "q" -> q, "target" -> t,
        "warmInitNumV" -> nW,
        "isESS" -> is["ESS"],
        "prodIter" -> prodIter, "prodAcc" -> prod["acceptRate"],
        "warmIter" -> warmIter, "warmAcc" -> warm["acceptRate"],
        "l1IsProd" -> l1IsP, "l1IsWarm" -> l1IsW,
        "l1ProdWarm" -> l1PW|>];
      Print[""]],
    {c, cells}];

  Print["================================================"];
  Print["SUMMARY  (warm vs production, q=10)"];
  Print["================================================"];
  Print["  ",
    StringPadRight["cell",     8],
    StringPadRight["target",   12],
    StringPadRight["IS ESS",   10],
    StringPadRight["prod acc", 10],
    StringPadRight["warm acc", 10],
    StringPadRight["L1(IS,P)", 11],
    StringPadRight["L1(IS,W)", 11],
    "L1(P,W)"];
  Do[
    Print["  ",
      StringPadRight["(" <> ToString[r["p"]] <> "," <>
                     ToString[r["q"]] <> ")", 8],
      StringPadRight[r["target"], 12],
      StringPadRight[ToString[NumberForm[r["isESS"], 4]], 10],
      StringPadRight[ToString[NumberForm[r["prodAcc"], {4, 3}]], 10],
      StringPadRight[ToString[NumberForm[r["warmAcc"], {4, 3}]], 10],
      StringPadRight[ToString[NumberForm[r["l1IsProd"],  {5, 4}]], 11],
      StringPadRight[ToString[NumberForm[r["l1IsWarm"],  {5, 4}]], 11],
      NumberForm[r["l1ProdWarm"], {5, 4}]],
    {r, results}];

  exportWxfAtomic[combFile["summary", "q10_warm_vs_prod"],
    <|"results" -> results, "createdAt" -> DateString[]|>];
  Print[""];
  Print["wrote q10_warm_vs_prod_summary.wxf"]];

(* ======================================================================
   results: every summary WXF that exists, as results/<name>.csv. One row
   per result (sampler_efficiency: one per cell x target x source); nested
   fields become name_field columns (otherStatL1_aut, classChi2_pValue);
   Missing values are empty cells, exact fractions become decimals.
   ====================================================================== *)
valJob["results"] := Module[{summaries, csvCell, flat, tableOf, n = 0},
  summaries = Join[
    ("validation_" <> # -> combFile["validationSummary", #]) & /@
      {"mh", "ecgexact", "ecgmcmc", "ecglegacyfacet"},
    (# -> combFile["summary", #]) & /@
      {"sampler_efficiency", "is_mh_truth_3way", "q10_is_vs_mh", "q10_warm_vs_prod"}];
  csvCell[x_Integer] := x;
  csvCell[x_?NumericQ] := N[x];
  csvCell[x_String] := x;
  csvCell[True] = "True"; csvCell[False] = "False";
  csvCell[_Missing] = "";
  csvCell[x_] := ToString[x, InputForm];
  flat[a_Association, prefix_String] := Join @@ KeyValueMap[
    If[AssociationQ[#2], flat[#2, prefix <> #1 <> "_"], <|prefix <> #1 -> #2|>] &, a];
  (* sampler_efficiency nests one row per source under each cell x target *)
  tableOf[results_List] := Module[{rows, cols},
    rows = Flatten[If[ListQ[#["rows"]],
        Function[s, Join[flat[KeyDrop[#, "rows"], ""], flat[s, ""]]] /@ #["rows"],
        {flat[#, ""]}] & /@ results];
    cols = DeleteDuplicates[Flatten[Keys /@ rows]];
    Prepend[Map[csvCell, Lookup[#, cols, Missing[]] & /@ rows, {2}], cols]];
  Do[With[{name = s[[1]], f = s[[2]]},
      If[FileExistsQ[f],
        exportCsvAtomic[combFile["results", name],
          tableOf[Import[f, "WXF"]["results"]],
          <|"inputs" -> {FileNameTake[f]}|>];
        n++;
        Print["  wrote ", combFile["results", name]],
        Print["  (no ", FileNameTake[f], ")"]]],
    {s, summaries}];
  Print["results: ", n, " table(s) in ", $CombResultsDir]];

valJob[valJobName];
