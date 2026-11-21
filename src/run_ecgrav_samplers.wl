(* run_ecgrav_samplers.wl
   Draw samples from the ECGrav exact/MCMC samplers and persist them in the same
   {headers, rows} layout as run_mh_chains.wl, so validate_mh_vs_truth.wl
   and the renderers can consume them unchanged.

   Samplers (COMB_ECG_SAMPLER):
     exact        target -> ECGrav function, n free (drawn from the counts):
                    unlabeled -> RandomUniformUnlabeledPureSimplicialComplex[{p,q}, B]
                    facet     -> RandomUniformFacetLabeledPureSimplicialComplex[{p,q}, B]
                    vertex    -> RandomVertexLabeledPureSimplicialComplex[{p,q}, B]
     mcmc         RandomPureSimplicialComplexMCMC[seed, {numV}, label, N]
                  (label 0 = vertex, 1 = facet, 2 = unlabeled). Samples are
                  spaced corrT sweeps apart by ECGrav itself. After the
                  sampling run, a separate per-sweep trace
                  (RandomPureSimplicialComplexMCMCSweep with NN = 1) is
                  recorded for our own τ_int estimate.
     legacyfacet  RandomFacetLabeledPureSimplicialComplex[{p,q}] — known
                  NON-uniform (docs/sampling.md). Negative control only:
                  the harness must FAIL it. Target must be "facet".

   Per sample we record the 12-stat row (statsFor, memoized on the BLISS
   canonical key since the stats are isomorphism invariants) and, when a
   truth WXF exists for the cell, the index of the matching truth iso
   class (0 = no match, which must never happen).

   Output: data/p{p}q{q}_ecg{sampler}_{target}.wxf

   Env:
     COMB_ECG_CELLS     "p,q;p,q"        default: the 9-cell truth grid
     COMB_ECG_TARGETS   "unlabeled,facet,vertex"
     COMB_ECG_SAMPLER   exact | mcmc | legacyfacet      default exact
     COMB_ECG_N         samples            default 100000 exact, 20000 mcmc
     COMB_ECG_BATCH     draw batch size    default 2000 (progress granularity)
     COMB_ECG_SEED      default 24680
     COMB_ECG_TRACE_STEPS  mcmc trace length in MH proposals
                        (default 200000, matching run_mh_chains.wl numIter)
     COMB_ECGRAV_DIR      see load_ecgrav.wl (default: shared upstream clone;
                          Phase 5a ran ECGrav 1.17.0, upstream d15739c)
     COMB_FORCE=1       overwrite existing WXF
*)

(* ===== Paths ===== *)
scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
Get[FileNameJoin[{scriptDir, "comb_paths.wl"}]];
Get[FileNameJoin[{scriptDir, "lib_names.wl"}]];
Get[FileNameJoin[{scriptDir, "lib_config.wl"}]];
outputDir = $CombDataDir;
If[!DirectoryQ[outputDir], CreateDirectory[outputDir]];

(* ===== Load ECGrav, then our helpers ===== *)
Get[FileNameJoin[{scriptDir, "load_ecgrav.wl"}]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator_bliss.wl"}]];
Get[FileNameJoin[{scriptDir, "lib_stats.wl"}]];
Get[FileNameJoin[{scriptDir, "lib_io.wl"}]];

(* ===== Defaults ===== *)
defaultCells = {{2, 4}, {2, 5}, {2, 6}, {2, 7},
                {3, 4}, {3, 5}, {3, 6},
                {4, 4}, {4, 5}};
defaultTargets = {"unlabeled", "facet", "vertex"};
statsHeaders = $CombStatsHeaders;
labelChoice = <|"vertex" -> 0, "facet" -> 1, "unlabeled" -> 2|>;

(* ===== Env parsing ===== *)
resolvedCells   = combSetting["COMB_ECG_CELLS", defaultCells, "cells"];
resolvedTargets = combSetting["COMB_ECG_TARGETS", defaultTargets, "list"];
samplerVal      = combSetting["COMB_ECG_SAMPLER", "exact"];
numSamplesVal   = combSetting["COMB_ECG_N",
  If[samplerVal === "mcmc", 20000, 100000], "expr"];
batchVal        = combSetting["COMB_ECG_BATCH", 2000, "expr"];
seedVal         = combSetting["COMB_ECG_SEED", 24680, "expr"];
traceStepsVal   = combSetting["COMB_ECG_TRACE_STEPS", 200000, "expr"];
forceRecompute  = combSetting["COMB_FORCE", False, "flag"];

If[!MemberQ[{"exact", "mcmc", "legacyfacet"}, samplerVal],
  Print["unknown COMB_ECG_SAMPLER: ", samplerVal]; Abort[]];
If[samplerVal === "legacyfacet", resolvedTargets = {"facet"}];

Print["outputDir       = ", outputDir];
Print["ECGrav          = ", $CombECGravVersion];
Print["sampler         = ", samplerVal];
Print["cells           = ", resolvedCells];
Print["targets         = ", resolvedTargets];
Print["N / batch / seed= ", numSamplesVal, " / ", batchVal, " / ", seedVal];
If[samplerVal === "mcmc", Print["trace steps     = ", traceStepsVal]];

outFile[p_, q_, t_] := FileNameJoin[{outputDir,
  combName["ecg", p, q, samplerVal, t]}];
truthFile[p_, q_] := FileNameJoin[{outputDir, combName["truth", p, q]}];

(* ===== Truth class lookup: canonical key -> 1-based truth index ===== *)
truthKeyIndex[p_, q_] := Module[{tf = truthFile[p, q], truth},
  If[!FileExistsQ[tf], Return[None]];
  truth = Import[tf, "WXF"];
  AssociationThread[
    (blissCanonicalKey[#["facets"]] & /@ truth["complexes"]) ->
      Range[Length[truth["complexes"]]]]];

(* ===== Sampler dispatch ===== *)
drawExact[p_, q_, "unlabeled", n_] :=
  RandomUniformUnlabeledPureSimplicialComplex[{p, q}, n];
drawExact[p_, q_, "facet", n_] :=
  RandomUniformFacetLabeledPureSimplicialComplex[{p, q}, n];
drawExact[p_, q_, "vertex", n_] :=
  RandomVertexLabeledPureSimplicialComplex[{p, q}, n];
drawLegacy[p_, q_, n_] :=
  Table[RandomFacetLabeledPureSimplicialComplex[{p, q}], {n}];

(* Warm the counters (ExpansionRoadmap.md §1.2: counter first, then draw). *)
warmCounters[p_, q_, target_] := Switch[target,
  "unlabeled", NumUnlabeledPureComplexes[p, q],
  "facet",     NumFacetLabeledPureComplexes[p, q],
  "vertex",    NumVertexLabeledPureComplexes[p, q]];

(* Draw N in batches with progress. Returns {complexes, seconds}. *)
drawBatched[drawFn_, n_] := Module[{done = 0, out = {}, t0, b, batch},
  t0 = AbsoluteTime[];
  While[done < n,
    b = Min[batchVal, n - done];
    batch = drawFn[b];
    If[!ListQ[batch], Print["    sampler returned ", batch]; Abort[]];
    out = Join[out, batch];
    done += b;
    Print["    drawn ", done, " / ", n, "   (",
      Round[AbsoluteTime[] - t0, 0.1], " s)"]];
  {out, AbsoluteTime[] - t0}];

(* ===== MCMC: sample run + separate per-sweep trace ===== *)
numVOp = Function[c, Length[Union @@ c]];

runMCMC[p_, q_, target_, n_] := Module[
  {seedC, res, meas, info, t0, secs, traceSweeps, state, trace, tt},
  seedC = RandomVertexLabeledPureSimplicialComplex[{p, q}];
  t0 = AbsoluteTime[];
  res = RandomPureSimplicialComplexMCMC[seedC, {numVOp},
    labelChoice[target], n];
  secs = AbsoluteTime[] - t0;
  If[res === $Failed || !ListQ[res],
    Print["    MCMC failed: ", res]; Return[$Failed]];
  {meas, info} = res;
  Print["    eqlT = ", info["eqlT"], "  corrT = ", info["corrT"],
    "  corrTMeasured = ", info["corrTMeasured"],
    "  converged = ", info["converged"], "  (", Round[secs, 0.1], " s)"];
  (* Per-sweep trace from the final state. One sweep = p q proposals. *)
  traceSweeps = Ceiling[traceStepsVal / (p q)];
  state = info["state"];
  tt = AbsoluteTiming[
    trace = Table[
      state = RandomPureSimplicialComplexMCMCSweep[state["complex"],
        labelChoice[target], 1];
      {state["vertexCount"], state["energy"]},
      {traceSweeps}]][[1]];
  Print["    trace: ", traceSweeps, " sweeps in ", Round[tt, 0.1], " s"];
  <|"complexes" -> meas[[All, -1]],
    "sampleSeconds" -> secs,
    "eqlT" -> info["eqlT"], "corrT" -> info["corrT"],
    "corrTValues" -> info["corrTValues"],
    "corrTMeasured" -> info["corrTMeasured"],
    "converged" -> Lookup[info, "converged", Missing[]],
    "traceSweeps" -> traceSweeps,
    "stepsPerSweep" -> p q,
    "traceNumV" -> trace[[All, 1]],
    "traceEnergy" -> trace[[All, 2]],
    "traceSeconds" -> tt|>];

(* ===== Per-cell × target ===== *)
processCellTarget[p_, q_, target_] := Module[
  {of, keyIdx, coldSecs, drawn, complexes, sampleSecs, extra = <||>,
   statsCache = <||>, keys, rows, classIdx, statsSecs, unmatched, payload},
  of = outFile[p, q, target];
  Print[""];
  Print["====================================="];
  Print["(p, q) = (", p, ", ", q, ")  target = ", target, "  sampler = ",
    samplerVal, "  -->  ", FileNameTake[of], "   started ", DateString[{"Year", "-", "Month", "-", "Day", " ", "Hour", ":", "Minute", ":", "Second"}]];
  If[FileExistsQ[of] && !forceRecompute,
    Print["  exists, skipping. COMB_FORCE=1 to override."]; Return[]];

  SeedRandom[seedVal];
  Switch[samplerVal,
    "exact",
      coldSecs = First @ AbsoluteTiming[
        warmCounters[p, q, target]; drawExact[p, q, target, 1]];
      Print["  cold (counter + first draw): ", Round[coldSecs, 0.001], " s"];
      {complexes, sampleSecs} =
        drawBatched[drawExact[p, q, target, #] &, numSamplesVal],
    "legacyfacet",
      coldSecs = First @ AbsoluteTiming[drawLegacy[p, q, 1]];
      {complexes, sampleSecs} = drawBatched[drawLegacy[p, q, #] &, numSamplesVal],
    "mcmc",
      coldSecs = Missing["NotApplicable"];
      drawn = runMCMC[p, q, target, numSamplesVal];
      If[drawn === $Failed, Return[$Failed]];
      complexes = drawn["complexes"];
      sampleSecs = drawn["sampleSeconds"];
      extra = KeyDrop[drawn, {"complexes", "sampleSeconds"}]];
  Print["  sampled ", Length[complexes], " in ", Round[sampleSecs, 0.1],
    " s  (", ToString[NumberForm[1000. sampleSecs/Length[complexes], {6, 3}]], " ms/sample)"];

  (* Stats + class index, memoized on the canonical key. *)
  keyIdx = truthKeyIndex[p, q];
  {statsSecs, {rows, classIdx}} = AbsoluteTiming[
    keys = blissCanonicalKey /@ complexes;
    {MapThread[
       Function[{k, c},
         If[KeyExistsQ[statsCache, k], statsCache[k],
           statsCache[k] = statsFor[c, p]]],
       {keys, complexes}],
     If[keyIdx === None, Missing["NoTruth"],
       Lookup[keyIdx, Key[#], 0] & /@ keys]}];
  Print["  stats + keys: ", Round[statsSecs, 0.1], " s  (",
    Length[statsCache], " distinct iso classes hit)"];
  If[ListQ[classIdx],
    unmatched = Count[classIdx, 0];
    Print["  truth classes: ", Length[keyIdx], "  hit: ",
      Length[DeleteCases[Union[classIdx], 0]],
      "  unmatched samples: ", unmatched,
      If[unmatched > 0, "   *** SAMPLES OUTSIDE TRUTH SUPPORT ***", ""]]];

  payload = Join[<|
    "p" -> p, "q" -> q, "target" -> target,
    "sampler" -> "ecg" <> samplerVal,
    "numSamples" -> Length[complexes],
    "seed" -> seedVal,
    "headers" -> statsHeaders,
    "rows" -> rows,
    "classIdx" -> classIdx,
    "numDistinctClasses" -> Length[statsCache],
    "coldSeconds" -> coldSecs,
    "wallSeconds" -> sampleSecs,
    "secondsPerSample" -> sampleSecs / Length[complexes],
    "statsSeconds" -> statsSecs,
    "ecGravVersion" -> $CombECGravVersion,
    "createdAt" -> DateString[]|>, extra];
  exportWxfAtomic[of, payload];
  Print["  wrote ", FileNameTake[of], " (",
    Round[FileByteCount[of]/1024.], " KB)"];
];

Do[
  Do[processCellTarget[cell[[1]], cell[[2]], t], {t, resolvedTargets}],
  {cell, resolvedCells}];
Print[""];
Print["done."];
