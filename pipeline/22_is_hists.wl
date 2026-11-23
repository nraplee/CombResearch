(* pipeline/22_is_hists.wl
   q=10 IS histograms (Phase 4 row 6). run.wl's is stage runs it after the
   merges (it replaced src/precompute_is_histograms_q10.wl, deleted in
   Phase 5).

   For p in {2, 3, 4}, from data/p{p}q10_merged_stats.wxf it writes
     data/p{p}q10_is_{target}_numv_hist.wxf   numV only, one per target
                                              (as before; read by the
                                              comparisons and the q=10 renders)
     data/p{p}q10_is_stat_hists.wxf           every statistic x the three
                                              targets x {all, connected}
                                              (PureComplexStatisticHistograms),
                                              so the figures never read the
                                              2.8 GB of merged stats
   Each file that already exists is skipped (COMB_FORCE=1 rewrites them), so
   on a store that has the numV files only the new file is written.

   Weights are converted to machine floats early: exact rationals make the
   ESS over 12M rows hopelessly slow.

   numV-hist schema (unchanged):
     <|"p"->p, "q"->10, "target"->t, "sourceN"->n, "ESS"->ess,
       "fracHist"-> <|numV -> frac, ...|>|>
   stat-hists schema: <|"p", "q", "sourceN", "filters" -> {"all",
     "connected"}, "targets", "statistics", "n" -> <|filter -> rows|>,
     "ESS" -> <|filter -> <|target -> ess|>|>,
     "hists" -> <|stat -> <|filter -> <|target -> <|value -> frac|>|>|>|>|>
   The fractions are normalized within each filter and leave out values
   that are not numbers (Betti numbers that do not apply at this p). The
   all-samples numV fractions equal the numV hist's up to float rounding. *)

$pipelineDir = DirectoryName[$InputFileName];
$commonDir = FileNameJoin[{$pipelineDir, "common"}];
Get[FileNameJoin[{$commonDir, "paths.wl"}]];
Get[FileNameJoin[{$commonDir, "names.wl"}]];
Get[FileNameJoin[{$commonDir, "io.wl"}]];
Get[FileNameJoin[{$commonDir, "config.wl"}]];
Get[FileNameJoin[{$commonDir, "combresearch.wl"}]];
dataDir = $CombDataDir;

targetColumn = <|"vertex" -> "wVertex", "unlabeled" -> "wUnlabeled",
                 "facet"  -> "wFacet"|>;

forceRecompute = combSetting["COMB_FORCE", False, "flag"];

(* Per-p cache: import the 12M-row stats file once, then drive all three
   target reweightings from the cached rows. *)
$cachedP = None;
$cachedRows = None;
$cachedHeaders = None;

ensureCache[p_] := If[$cachedP =!= p,
  Module[{srcFile, t0, data},
    srcFile = combFile["isStats", combMergedStem[p, 10]];
    Print["  loading ", FileNameTake[srcFile], " ..."];
    t0 = AbsoluteTime[];
    data = Import[srcFile];
    $cachedRows    = data["rows"];
    $cachedHeaders = data["headers"];
    $cachedP       = p;
    Print["    ", Length[$cachedRows], " rows in ",
      Round[AbsoluteTime[] - t0, 0.01], "s"]]];

haveFile[f_] := FileExistsQ[f] && FileByteCount[f] > 0 && !forceRecompute;

processOne[p_, target_] := Module[
  {outFile, numVs, col, w, ess, frac, t0},
  outFile = combFile["isHist", p, 10, target];

  Print["====  p=", p, "  target=", target, "  ===="];
  If[haveFile[outFile],
    Print["  skip: already exists (", FileNameTake[outFile],
      ", ", Round[FileByteCount[outFile]/1024., 0.1],
      " KB).  COMB_FORCE=1 to override."];
    Print[""];
    Return[]];

  ensureCache[p];
  numVs = $cachedRows[[All, 1]];
  col   = Position[$cachedHeaders, targetColumn[target]][[1, 1]];
  t0 = AbsoluteTime[];
  w = N[$cachedRows[[All, col]]];   (* float early *)
  Print["  weights -> float in ", Round[AbsoluteTime[] - t0, 0.01], "s"];

  t0 = AbsoluteTime[];
  ess = Total[w]^2 / Total[w^2];
  Print["  ESS = ", NumberForm[ess, 5],
    "  (in ", Round[AbsoluteTime[] - t0, 0.01], "s)"];

  (* GroupBy is much faster than Merge[Thread[..., Total]] at 2M+ rows. *)
  t0 = AbsoluteTime[];
  frac = SampleHistogram[numVs, w];
  Print["  aggregated ", Length[frac], " bins in ",
    Round[AbsoluteTime[] - t0, 0.01], "s"];
  Print["  bins / frac:"];
  Do[Print["    numV=", k, "  frac=", NumberForm[frac[k], {6, 5}]],
    {k, Keys[frac]}];

  exportWxfAtomic[outFile, <|"p" -> p, "q" -> 10, "target" -> target,
    "sourceN" -> Length[$cachedRows], "ESS" -> ess,
    "fracHist" -> frac|>,
    <|"inputs" -> {combName["isStats", combMergedStem[p, 10]]}|>];
  Print["  wrote ", FileNameTake[outFile]];
  Print[""]];

processStats[p_] := Module[{outFile, res, t0},
  outFile = combFile["isStatHists", p, 10];
  Print["====  p=", p, "  every statistic  ===="];
  If[haveFile[outFile],
    Print["  skip: already exists (", FileNameTake[outFile], ").  COMB_FORCE=1 to override."];
    Print[""];
    Return[]];
  ensureCache[p];
  t0 = AbsoluteTime[];
  res = PureComplexStatisticHistograms[$cachedHeaders, $cachedRows];
  Print["  ", Length[res["statistics"]], " statistics x ", Length[res["targets"]],
    " targets x ", Length[res["filters"]], " filters in ",
    Round[AbsoluteTime[] - t0, 0.01], "s"];
  Do[Print["    ", f, ": n = ", res["n"][f], "  ESS ",
      StringRiffle[KeyValueMap[#1 <> " " <> ToString[NumberForm[#2, 5]] &, res["ESS"][f]], ", "]],
    {f, res["filters"]}];
  exportWxfAtomic[outFile, Join[<|"p" -> p, "q" -> 10|>, res],
    <|"inputs" -> {combName["isStats", combMergedStem[p, 10]]}|>];
  Print["  wrote ", FileNameTake[outFile]];
  Print[""]];

Do[
  Do[processOne[p, target], {target, {"vertex", "unlabeled", "facet"}}];
  processStats[p],
  {p, {2, 3, 4}}];

Print["Done."];
