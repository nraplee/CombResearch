(* run_mh_chains.wl
   Phase 3 chain-persistence sister to enumerate_truth.wl. For each
   reachable (p, q) cell and each target measure, run the MH sampler,
   compute a 12-stat row per kept post-thin state, and persist a single
   WXF cache per cell × target.

   Reachable grid (Phase 2): {(2,4), (2,5), (2,6), (3,4), (3,5)}.
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
       "samplerVersion" -> "sampler_mh.wl@<sha>",
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

   Validation gate (deferred from Phase 2): when (p,q,target) ==
   (3, 5, "unlabeled") is freshly computed, immediately load
   data/p3q5_truth.wxf, marginalize piUnlabeled onto numV, bin chain
   numV the same way, compute L1, abort if >= 0.05. Single-shot check —
   does not fire on subsequent skip-if-exists invocations.

   IMPORTANT: must NOT shadow runMHChain's option names {burnIn, thin,
   seed, verbose, kernel} in the surrounding scope, since those are
   global symbols. Local config uses suffixed names: burnInVal, thinVal,
   seedVal, kernelVal, etc. *)

(* ===== Paths ===== *)
scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
outputDir = FileNameJoin[{projectRoot, "data"}];
If[!DirectoryQ[outputDir], CreateDirectory[outputDir]];

(* ===== Load sampler_mh.wl with smoke test suppressed ===== *)
$smokeTestSkip = True;
Get[FileNameJoin[{scriptDir, "sampler_mh.wl"}]];

(* ===== Pull statsFor + helpers from pure_simplicial_compute.wl =====
   The Get'd script also runs a per-p sampling loop on load; suppress
   it by passing pListOverride={} and sampleSizeOverride=0. Definitions
   (oneSkeleton, statsFor, exportWxfAtomic, etc.) persist. *)
Block[{pListOverride = {}, sampleSizeOverride = 0,
       useParallelOverride = False},
  Get[FileNameJoin[{scriptDir, "pure_simplicial_compute.wl"}]]];

(* ===== Defaults ===== *)
defaultCells = {{2, 4}, {2, 5}, {2, 6}, {3, 4}, {3, 5}};
defaultTargets = {"unlabeled", "facet", "vertex"};
statsHeaders = {"numV", "aut", "autF", "connected",
  "num1VConnComps", "num2VConnComps", "largestCompRatio",
  "num2PathConnComps", "num3PathConnComps",
  "Betti1", "Betti2", "Betti3"};

(* ===== Env parsing ===== *)
parseEnvCells[s_String] := Module[{pairs},
  pairs = StringSplit[StringTrim[s], ";"];
  pairs = StringSplit[#, ","] & /@ pairs;
  ToExpression /@ # & /@ pairs];

parseEnvList[s_String] := StringTrim /@ StringSplit[StringTrim[s], ","];

parseIntEnv[name_, default_] := With[{e = Environment[name]},
  If[StringQ[e] && StringLength[e] > 0,
    ToExpression[e], default]];

parseStringEnv[name_, default_] := With[{e = Environment[name]},
  If[StringQ[e] && StringLength[e] > 0, e, default]];

resolvedCells = Which[
  StringQ[Environment["COMB_MH_CELLS"]] &&
    StringLength[Environment["COMB_MH_CELLS"]] > 0,
    parseEnvCells[Environment["COMB_MH_CELLS"]],
  True, defaultCells];

resolvedTargets = Which[
  StringQ[Environment["COMB_MH_TARGETS"]] &&
    StringLength[Environment["COMB_MH_TARGETS"]] > 0,
    parseEnvList[Environment["COMB_MH_TARGETS"]],
  True, defaultTargets];

numIterVal  = parseIntEnv["COMB_MH_NUMITER", 200000];
burnInVal   = parseIntEnv["COMB_MH_BURNIN",   20000];
thinVal     = parseIntEnv["COMB_MH_THIN",         5];
seedVal     = parseIntEnv["COMB_MH_SEED",     12345];
kernelVal   = parseStringEnv["COMB_MH_KERNEL", "global"];
forceRecompute = With[{e = Environment["COMB_FORCE"]},
  StringQ[e] && e === "1"];

(* ===== Provenance ===== *)
samplerVersion = Module[{res, sha},
  res = Quiet @ RunProcess[{
    "git", "-C", projectRoot, "rev-parse", "--short", "HEAD"}];
  If[AssociationQ[res] && res["ExitCode"] === 0,
    sha = StringTrim[res["StandardOutput"]];
    "sampler_mh.wl@" <> sha,
    "sampler_mh.wl@unknown"]];

Print["scriptDir         = ", scriptDir];
Print["outputDir         = ", outputDir];
Print["resolvedCells     = ", resolvedCells];
Print["resolvedTargets   = ", resolvedTargets];
Print["numIter / burnIn  = ", numIterVal, " / ", burnInVal];
Print["thin / seed       = ", thinVal, " / ", seedVal];
Print["kernel            = ", kernelVal];
Print["forceRecompute    = ", forceRecompute];
Print["samplerVersion    = ", samplerVersion];

(* ===== Per-cell paths ===== *)
mhFile[p_Integer, q_Integer, target_String] := FileNameJoin[{outputDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <>
  "_mh_" <> target <> ".wxf"}];

truthFile[p_Integer, q_Integer] := FileNameJoin[{outputDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth.wxf"}];

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
  result = runMHChain[p, q, target, numIterVal,
    burnIn -> burnInVal, thin -> thinVal,
    seed   -> seedVal,   kernel -> kernelVal];

  (* ----- Compute 12-stat row per kept post-thin state ----- *)
  Print["  computing ", Length[result["trace"]], " stats rows ..."];
  {statsTime, rows} = AbsoluteTiming[
    statsFor[#, p] & /@ result["trace"]];
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

  (* ----- Validation gate: (3,5) × unlabeled vs truth on numV ----- *)
  If[p == 3 && q == 5 && target == "unlabeled",
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
