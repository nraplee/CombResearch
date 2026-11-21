(* precompute_is_histograms_q10.wl
   Aggregate the merged 12M-row q=10 IS data into small numV histograms
   under all three target reweightings (vertex / unlabeled / facet) for
   p in {2, 3, 4}. Writes nine small WXFs into data/ for later overlay
   against MH chains.

   Generalizes the earlier p=4 unlabeled-only `precompute_is_histogram.wl`.
   Weights are converted to machine floats early — exact rationals make
   ESS computation over 12M rows hopelessly slow.

   Output schema per file (data/p{p}q10_is_{target}_numv_hist.wxf):
     <|"p"->p, "q"->10, "target"->t, "sourceN"->n, "ESS"->ess,
       "fracHist"-> <|numV -> frac, ...|>|>

   Reads and writes $CombDataDir (the main checkout data/, see
   comb_paths.wl), also when run from a worktree.
*)

Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "lib_names.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "lib_io.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "lib_config.wl"}]];
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

processOne[p_, target_] := Module[
  {outFile, numVs, col, w, ess, hist, total, frac, t0},
  outFile = combFile["isHist", p, 10, target];

  Print["====  p=", p, "  target=", target, "  ===="];
  If[FileExistsQ[outFile] && FileByteCount[outFile] > 0 && !forceRecompute,
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
  hist = Total /@ GroupBy[Transpose[{numVs, w}], First -> Last];
  total = Total[Values[hist]];
  frac = KeySort @ AssociationThread[Keys[hist] -> Values[hist] / total];
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

Do[
  Do[processOne[p, target], {target, {"vertex", "unlabeled", "facet"}}],
  {p, {2, 3, 4}}];

Print["Done."];
