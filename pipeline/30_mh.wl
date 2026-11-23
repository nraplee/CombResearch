(* pipeline/30_mh.wl
   MH stage (Phase 4): run.wl's mh stage runs this; it replaced
   src/run_mh_chains.wl (deleted in Phase 5); bare runs and the launchers behave as
   before (same knobs, same defaults, same file names). The sampler and the
   statistics come from the CombResearch package (PureComplexMHChain,
   PureComplexStatistics).

   MH chain-persistence driver. For each requested (p, q) cell and target,
   run the MH sampler, compute a 12-stat row per kept post-thin state, and
   persist a WXF cache per cell × target.

   Default grid is the original Phase 2 smoke grid; set COMB_MH_CELLS for
   newer cells such as (2,7), (3,6), (4,4), and (4,5).
   Targets: {"unlabeled", "facet", "vertex"}.

   Output: data/p{p}q{q}_mh_{target}.wxf, schema:
     <|
       "p" -> p, "q" -> q, "target" -> "unlabeled"|"facet"|"vertex",
       "kernel" -> "global", "numIter" -> 200000,
       "burnIn" -> 20000, "thin" -> 5, "seed" -> 12345,
       "headers" -> {"numV","aut","autF","connected","num1VConnComps",
                     "num2VConnComps","largestCompRatio",
                     "num2PathConnComps","num3PathConnComps",
                     "Betti1","Betti2","Betti3"},
       "rows" -> {{...}, ...},          (* one row per kept state *)
       "acceptRate" -> ..., "deltaNumVCounts" -> <|...|>,
       "wallSeconds" -> ...,
       "samplerVersion" -> "CombResearch/MHSampler.wl@<sha>"
                             (before Phase 4: "sampler_mh.wl@<sha>"),
       "createdAt" -> ...|>

   Idempotent: skips cells × targets whose WXF already exists and is
   non-empty. Force-recompute via env var COMB_FORCE=1.

   Env overrides:
     COMB_MH_CELLS    = "p,q;p,q;..."     (default reachable grid)
     COMB_MH_TARGETS  = "t1,t2,..."       (default unlabeled,facet,vertex)
     COMB_MH_NUMITER  = integer           (default 200000)
     COMB_MH_BURNIN   = integer           (default 20000)
     COMB_MH_THIN     = integer           (default 5)
     COMB_MH_SEED     = integer           (default 12345)
     COMB_MH_KERNEL   = string            (default "global")
     COMB_MH_TAG      = string            (default ""; appended to output
                                          stem, e.g. "_seed67890_warm18")
     COMB_MH_INITNUMV = integer or unset  (default unset; if set, chain
                                          init is q random p-subsets of
                                          [INITNUMV], embedded in [N=qp])

   Historical inline gate: when (p,q,target) ==
   (3, 5, "unlabeled") is freshly computed, immediately load
   data/p3q5_truth.wxf, marginalize piUnlabeled onto numV, bin chain
   numV the same way, compute L1, abort if >= 0.05. Single-shot check —
   does not fire on subsequent skip-if-exists invocations.

   Local config uses suffixed names (burnInVal, thinVal, seedVal,
   kernelVal, ...); the sampler's options are strings ("burnIn" -> ...). *)

(* ===== Paths + libraries ===== *)
$pipelineDir = DirectoryName[$InputFileName];
$commonDir = FileNameJoin[{$pipelineDir, "common"}];
Get[FileNameJoin[{$commonDir, "combresearch.wl"}]];
Get[FileNameJoin[{$commonDir, "paths.wl"}]];
Get[FileNameJoin[{$commonDir, "names.wl"}]];
Get[FileNameJoin[{$commonDir, "config.wl"}]];
Get[FileNameJoin[{$commonDir, "io.wl"}]];

(* COMB_MH_OUTDIR overrides the shared data dir. *)
outputDir = combSetting["COMB_MH_OUTDIR", $CombDataDir];
If[!DirectoryQ[outputDir], CreateDirectory[outputDir]];

(* ===== Defaults ===== *)
defaultCells = {{2, 4}, {2, 5}, {2, 6}, {3, 4}, {3, 5}};
defaultTargets = {"unlabeled", "facet", "vertex"};
statsHeaders = $PureComplexStatisticNames;

(* ===== Env parsing ===== *)
resolvedCells = combSetting["COMB_MH_CELLS", defaultCells, "cells"];

resolvedTargets = combSetting["COMB_MH_TARGETS", defaultTargets, "list"];

numIterVal  = combSetting["COMB_MH_NUMITER", 200000, "expr"];
burnInVal   = combSetting["COMB_MH_BURNIN",   20000, "expr"];
thinVal     = combSetting["COMB_MH_THIN",         5, "expr"];
seedVal     = combSetting["COMB_MH_SEED",     12345, "expr"];
kernelVal   = combSetting["COMB_MH_KERNEL", "global"];
tagVal      = combSetting["COMB_MH_TAG",         ""];
initNumVVal = combSetting["COMB_MH_INITNUMV", Automatic, "expr"];
forceRecompute = combSetting["COMB_FORCE", False, "flag"];

(* ===== Provenance ===== *)
samplerVersion = Module[{res, sha},
  res = Quiet @ RunProcess[{
    "git", "-C", $pipelineDir, "rev-parse", "--short", "HEAD"}];
  If[AssociationQ[res] && res["ExitCode"] === 0,
    sha = StringTrim[res["StandardOutput"]];
    "CombResearch/MHSampler.wl@" <> sha,
    "CombResearch/MHSampler.wl@unknown"]];

Print["codeDir           = ", ParentDirectory[$pipelineDir]];
Print["outputDir         = ", outputDir];
Print["resolvedCells     = ", resolvedCells];
Print["resolvedTargets   = ", resolvedTargets];
Print["numIter / burnIn  = ", numIterVal, " / ", burnInVal];
Print["thin / seed       = ", thinVal, " / ", seedVal];
Print["kernel            = ", kernelVal];
Print["tag               = ", "\"" <> tagVal <> "\""];
Print["initNumV          = ", initNumVVal];
Print["forceRecompute    = ", forceRecompute];
Print["samplerVersion    = ", samplerVersion];

(* ===== Per-cell paths ===== *)
mhFile[p_Integer, q_Integer, target_String] := FileNameJoin[{outputDir,
  combName["mh", p, q, target, tagVal]}];

truthFile[p_Integer, q_Integer] := FileNameJoin[{outputDir,
  combName["truth", p, q]}];

(* ===== L1 helper for the (3,5) validation gate =====
   Marginalize truth's piUnlabeled onto numV, bin chain numV the same
   way, compute total-variation distance. *)
truthVsMhNumVL1[truth_Association, rows_List] := Module[
  {truthVals, piU, mhVals, truthBars, mhBars, allKeys, truthVec, mhVec},
  truthVals = (#["stats"]["numV"]) & /@ truth["complexes"];
  piU       = truth["piUnlabeled"];
  truthBars = Merge[Thread[truthVals -> piU], Total];
  mhVals    = rows[[All, 1]];   (* numV is column 1 *)
  mhVals    = Select[mhVals, NumericQ];
  If[Length[mhVals] == 0, Return[$Failed]];
  mhBars    = N[Counts[mhVals] / Length[mhVals]];
  allKeys   = Union[Keys[truthBars], Keys[mhBars]];
  truthVec  = Lookup[truthBars, #, 0] & /@ allKeys;
  mhVec     = Lookup[mhBars,    #, 0] & /@ allKeys;
  Total[Abs[N[truthVec] - N[mhVec]]]];

(* ===== Per-cell × target pipeline ===== *)
processCellTarget[p_Integer, q_Integer, target_String] := Module[
  {outFile, result, statsTime, rows, payload, gateFile, truth, l1},

  outFile = mhFile[p, q, target];

  Print[""];
  Print["====================================="];
  Print["(p, q) = (", p, ", ", q, ")  target = ", target,
    "  -->  ", FileNameTake[outFile]];

  If[FileExistsQ[outFile] && FileByteCount[outFile] > 0 && !forceRecompute,
    Print["  WXF already exists (",
      Round[FileByteCount[outFile]/1024., 0.1],
      " KB), skipping. Set COMB_FORCE=1 to override."];
    Return[]];

  (* ----- Run the chain ----- *)
  result = PureComplexMHChain[p, q, target, numIterVal,
    "burnIn" -> burnInVal, "thin" -> thinVal,
    "seed"   -> seedVal,   "kernel" -> kernelVal,
    "initNumV" -> initNumVVal];
  If[!AssociationQ[result],
    Print["  *** FAIL: PureComplexMHChain returned ", Short[result]]; Exit[1]];

  (* ----- Compute 12-stat row per kept post-thin state ----- *)
  Print["  computing ", Length[result["trace"]], " stats rows ..."];
  {statsTime, rows} = AbsoluteTiming[
    PureComplexStatistics[#, p] & /@ result["trace"]];
  Print["    stats time : ", Round[statsTime, 0.01], "s"];

  (* ----- Persist ----- *)
  payload = <|
    "p"               -> p,
    "q"               -> q,
    "target"          -> target,
    "kernel"          -> kernelVal,
    "numIter"         -> numIterVal,
    "burnIn"          -> burnInVal,
    "thin"            -> thinVal,
    "seed"            -> seedVal,
    "tag"             -> tagVal,
    "initNumV"        -> initNumVVal,
    "headers"         -> statsHeaders,
    "rows"            -> rows,
    "acceptRate"      -> result["acceptRate"],
    "deltaNumVCounts" -> result["deltaNumVCounts"],
    "wallSeconds"     -> result["wallSeconds"],
    "samplerVersion"  -> samplerVersion,
    "createdAt"       -> DateString[]|>;

  exportWxfAtomic[outFile, payload];
  Print["  wrote ", FileNameTake[outFile],
    "  (", Round[FileByteCount[outFile] / 1024., 0.1], " KB)"];

  (* ----- Validation gate: (3,5) × unlabeled vs truth on numV -----
     Skip if non-default tag or warm-start init in play — the gate is
     for catching sampler regressions on the production case. *)
  If[p == 3 && q == 5 && target == "unlabeled"
       && tagVal === "" && initNumVVal === Automatic,
    gateFile = truthFile[3, 5];
    If[FileExistsQ[gateFile],
      truth = Import[gateFile, "WXF"];
      l1 = truthVsMhNumVL1[truth, rows];
      Print["  (3,5) numV L1(truth, MH unlabeled): ",
        ToString[NumberForm[l1, {6, 4}]]];
      If[l1 === $Failed,
        Print["  *** GATE FAIL: L1 computation returned $Failed ***"];
        Abort[]];
      If[l1 >= 0.05,
        Print["  *** GATE FAIL: L1 ", l1, " >= 0.05 threshold ***"];
        Abort[],
        Print["    GATE PASS (< 0.05)"]],
      Print["  (skipping gate: no truth WXF at ", FileNameTake[gateFile], ")"]]]];

(* ===== Driver ===== *)
Do[
  Module[{p = cell[[1]], q = cell[[2]]},
    Do[
      processCellTarget[p, q, target],
      {target, resolvedTargets}]],
  {cell, resolvedCells}];

Print[""];
Print["====================================="];
Print["Done."];
