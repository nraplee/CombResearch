(* pipeline/20_is_q10.wl
   q=10 importance-sampling stage (Phase 4). Sampling, statistics and
   weights come from the CombResearch package (RandomVertexLabeled... via
   ECGrav, PureComplexStatistics, PureComplexISWeights, EffectiveSampleSize).

   Knobs (combSetting; an *Override variable set before Get-ting this file
   still wins, as in Phase 4):
     COMB_IS_PS    "2,3,4"  the p values (pListOverride)        default {2,3,4}
     COMB_N        samples per p (sampleSizeOverride)           default 10000
     COMB_IS_PAR   1|0  ParallelMap the stats (useParallelOverride) default 0
     COMB_NN_FIXED, COMB_RUNTAG, COMB_CHUNK  (below)
   run.wl is launches one process per p and batch with COMB_IS_PS = p,
   COMB_IS_PAR = 1 (Phase 5: this replaces the run_p{2,3,4}.wl wrappers).

   Sampling + per-sample statistics pipeline for Figures 3-16.
   Pure simplicial complexes, q = 10, p in {2, 3, 4}.
   Produces two WXF files per p per session:
     {stem}_stats.wxf     — Association with headers, rows, metadata (stats + weights)
     {stem}_complexes.wxf — Association with the raw sampled complexes
   Independent of histograms_handoff_v2.nb / histograms_paper_figures.nb. *)

$pipelineDir = DirectoryName[$InputFileName];
$srcDir = FileNameJoin[{ParentDirectory[$pipelineDir], "src"}];
Get[FileNameJoin[{$srcDir, "load_combresearch.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_config.wl"}]];

(* ===== Parameters ===== *)
qVal = 10;
pList = If[ValueQ[pListOverride], pListOverride,
  combSetting["COMB_IS_PS", {2, 3, 4}, "intList"]];
sampleSize = If[ValueQ[sampleSizeOverride], sampleSizeOverride,
  combSetting["COMB_N", 10000, "expr"]];
randomSeed = 123456;

(* ===== Optional fixed-numV mode (Betre, 2026-05-05) =====
   When nnFixed is set, sampling uses the 3-arg form
     RandomVertexLabeledPureSimplicialComplex[{p, qVal, nnFixed}, thisN]
   which conditions on numV = nnFixed. The reweighting weights become
   constants across samples (same numV ⇒ same denominators), so the
   ESS heavy-tail at q=10 disappears. Bars produced are CONDITIONAL
   probabilities π(· | numV = nnFixed), not the marginal.
   The 3-arg form is absent from ECGrav 1.0.0. *)
nnFixed = If[ValueQ[nnFixedOverride], nnFixedOverride,
  combSetting["COMB_NN_FIXED", None, "expr"]];

(* Optional run tag. When set (e.g. via env var COMB_RUNTAG="batch2") the output
   filename becomes p{p}q10_n{N}_{runTag}_samples.csv AND the per-chunk seed is
   offset by a deterministic hash of the tag. This lets a fresh run produce
   fully independent samples that can be concatenated with a prior run via
   pipeline/21_is_merge.wl, without colliding on seeds. *)
runTag = If[ValueQ[runTagOverride], runTagOverride,
  combSetting["COMB_RUNTAG", ""]];
runSeedOffset = If[runTag === "", 0,
  Mod[Hash[runTag, "MD5"], 10^7]];

(* Output goes to $CombDataDir (main checkout data/, see comb_paths.wl). *)
Get[FileNameJoin[{$srcDir, "comb_paths.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_names.wl"}]];
outputDir = $CombDataDir;
If[!DirectoryQ[outputDir], CreateDirectory[outputDir]];

(* Optional ParallelMap over the per-sample stats step.
   COMB_IS_PAR=1, or useParallelOverride = True before Get'ing this script. *)
useParallel = If[ValueQ[useParallelOverride], useParallelOverride,
  combSetting["COMB_IS_PAR", False, "notZero"]];

Print["sampleSize    = ", sampleSize];
Print["pList         = ", pList];
Print["nnFixed       = ", If[nnFixed === None, "(none, variable n)", nnFixed]];
Print["outputDir     = ", outputDir];
Print["useParallel   = ", useParallel];
Print["runTag        = ", If[runTag === "", "(none)", runTag]];
Print["runSeedOffset = ", runSeedOffset];

(* ===== Atomic WXF export (statistics come from the package) ===== *)
Get[FileNameJoin[{$srcDir, "lib_io.wl"}]];

(* ===== Parallel kernel setup (only when useParallel=True) ===== *)
If[useParallel,
  Print["launching parallel kernels ..."];
  LaunchKernels[];
  Print["  ", Length[Kernels[]], " kernels active"];
  combLoadCombResearchOnKernels[]];  (* ECGrav + the package on every subkernel *)

(* ===== Main loop with checkpointing =====
   Per-p chunk files `..._chunk_k_{stats,complexes}.wxf` are written atomically
   (tmp + rename). A chunk is "done" only when BOTH files are present.
   On restart we skip any p whose final stats WXF exists; for a partially-done
   p we resume at the first chunk missing either file. At most one chunk
   (~11 min on p=4) is redone after a crash. *)

headers = $PureComplexISNames;

chunkSize = If[ValueQ[chunkSizeOverride], chunkSizeOverride,
  combSetting["COMB_CHUNK", 25000, "expr"]];
numChunks = Ceiling[sampleSize / chunkSize];
chunkSizeFor[k_] := If[k == numChunks,
  sampleSize - (numChunks - 1) * chunkSize, chunkSize];

baseStem[p_] := combISStem[p, qVal, sampleSize, nnFixed, runTag];
chunkStatsFile[p_, k_] := FileNameJoin[{outputDir,
  combName["isChunkStats", baseStem[p], k]}];
chunkComplexesFile[p_, k_] := FileNameJoin[{outputDir,
  combName["isChunkComplexes", baseStem[p], k]}];
finalStatsFile[p_] := FileNameJoin[{outputDir,
  combName["isStats", baseStem[p]]}];
finalComplexesFile[p_] := FileNameJoin[{outputDir,
  combName["isComplexes", baseStem[p]]}];

firstMissingChunk[p_] := Module[{k = 1},
  While[k <= numChunks &&
      FileExistsQ[chunkStatsFile[p, k]] &&
      FileExistsQ[chunkComplexesFile[p, k]],
    k++]; k];

(* Per-chunk files hold bare lists — the Association wrapper with metadata is
   only applied at the final consolidated file. *)
exportChunkAtomic[p_, k_, sample_, rows_] := (
  exportWxfAtomic[chunkStatsFile[p, k], rows, None];
  exportWxfAtomic[chunkComplexesFile[p, k], sample, None]);

(* Manifest extras for the final IS files: how the per-chunk seeds were made. *)
isManifestExtra[p_] := <|"seedRule" ->
    "SeedRandom[randomSeed + runSeedOffset + 1000 p + k], k = chunk",
  "randomSeed" -> randomSeed, "runSeedOffset" -> runSeedOffset,
  "runTag" -> runTag, "sampleSize" -> sampleSize, "chunkSize" -> chunkSize,
  "nnFixed" -> nnFixed|>;

consolidateChunks[p_] := Module[{allRows, allComplexes, n, statsAssoc, complexesAssoc},
  allRows      = Join @@ (Import[chunkStatsFile[p, #], "WXF"] & /@ Range[numChunks]);
  allComplexes = Join @@ (Import[chunkComplexesFile[p, #], "WXF"] & /@ Range[numChunks]);
  n = Length[allRows];
  statsAssoc = <|
    "headers"   -> headers,
    "rows"      -> allRows,
    "p"         -> p,
    "q"         -> qVal,
    "n"         -> n,
    "runTag"    -> runTag,
    "createdAt" -> DateString[]|>;
  complexesAssoc = <|
    "complexes" -> allComplexes,
    "p"         -> p,
    "q"         -> qVal,
    "n"         -> n,
    "runTag"    -> runTag,
    "createdAt" -> DateString[]|>;
  exportWxfAtomic[finalStatsFile[p],     statsAssoc,     isManifestExtra[p]];
  exportWxfAtomic[finalComplexesFile[p], complexesAssoc, isManifestExtra[p]];
  Do[
    DeleteFile[chunkStatsFile[p, k]];
    DeleteFile[chunkComplexesFile[p, k]],
    {k, numChunks}];
  Print["  consolidated ", n, " rows → ",
    FileNameTake[finalStatsFile[p]], " + ",
    FileNameTake[finalComplexesFile[p]]];
  allRows];

reportESS[p_, allRows_] := Module[{essU, essF},
  essU = EffectiveSampleSize[allRows[[All, 14]]];
  essF = EffectiveSampleSize[allRows[[All, 15]]];
  Print["  ESS unlabeled: ", Round[essU], " / ", sampleSize,
    " (", ToString[NumberForm[100. essU / sampleSize, {4, 2}]], "%)"];
  Print["  ESS facet    : ", Round[essF], " / ", sampleSize,
    " (", ToString[NumberForm[100. essF / sampleSize, {4, 2}]], "%)"]];

Do[
  Print["-----------------------------------------"];
  Print["p = ", p, ", q = ", qVal, ", N = ", sampleSize,
    ", chunkSize = ", chunkSize, ", numChunks = ", numChunks];

  If[FileExistsQ[finalStatsFile[p]] && FileExistsQ[finalComplexesFile[p]],
    Print["  final WXF files already present — skipping p = ", p],
   (* else *)
    Module[{startK = firstMissingChunk[p]},
      If[startK > 1, Print["  resuming at chunk ", startK, " / ", numChunks]];

      Do[
        Module[{thisN = chunkSizeFor[k], tSample, tStats, sample,
                statsRows, rows},
          Print["  chunk ", k, "/", numChunks, " (n=", thisN, ")"];
          SeedRandom[randomSeed + runSeedOffset + p*1000 + k];

          tSample = First @ AbsoluteTiming[
            sample = RandomVertexLabeledPureSimplicialComplex[
              If[nnFixed === None, {p, qVal}, {p, qVal, nnFixed}],
              thisN]];
          Print["    sampling : ", tSample, " s"];

          tStats = First @ AbsoluteTiming[
            statsRows = If[useParallel,
              ParallelMap[PureComplexStatistics[#, p] &, sample],
              PureComplexStatistics[#, p] & /@ sample]];
          Print["    stats    : ", tStats, " s"];

          rows = PureComplexISWeights[statsRows, qVal];

          exportChunkAtomic[p, k, sample, rows];
          Print["    wrote chunk files"]],
        {k, startK, numChunks}];

      reportESS[p, consolidateChunks[p]]]],
  {p, pList}];

Print["-----------------------------------------"];
Print["Done."];
