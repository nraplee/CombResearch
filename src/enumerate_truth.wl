(* enumerate_truth.wl
   Truth-enumeration driver. For each requested (p, q), run one of the
   streaming enumerators, compute per-iso-class statistics and the three exact
   distributions, and persist a WXF cache.

   Output: data/p{p}q{q}_truth.wxf, schema:
     <|
       "p" -> p, "q" -> q,
       "numIsoClasses"     -> Length[isoReps],
       "totalFacetLabeled" -> sr["totalEmitted"],
       "numBuckets"        -> sr["numBuckets"],
       "complexes"         -> {<|"facets"->..., "aut"->..., "autF"->...,
                                 "nV"->..., "stats"-><|...|>|>, ...},
       "piVertex"          -> {N, ...},     (* normalized π_V over iso classes *)
       "piFacet"           -> {N, ...},     (* normalized π_F over iso classes *)
       "piUnlabeled"       -> {N, ...},     (* uniform 1/numIsoClasses *)
       "wallClockSec"      -> ...,
       "peakMemMB"         -> ...,
       "ecGravVersion"     -> "1.0.0",
       "enumeratorVersion" -> "streaming_enumerator.wl@<sha>",
       "createdAt"         -> ...|>

   Idempotent: skips cells whose WXF already exists and is non-empty.
   Force-recompute via env var COMB_FORCE=1.
   Restrict cells via env var COMB_TRUTH_CELLS="p,q;p,q;...".

   Validation gates cover the default small grid. Add expected counts below
   when widening the default grid. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "load_ecgrav.wl"}]];

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
outputDir = FileNameJoin[{projectRoot, "data"}];
If[!DirectoryQ[outputDir], CreateDirectory[outputDir]];

(* ===== Load streaming enumerators =====
   Always load all three; the pipeline choice (env var, below) selects
   which one drives the run. *)
Get[FileNameJoin[{scriptDir, "streaming_enumerator.wl"}]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator_bliss.wl"}]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator_mckay.wl"}]];

(* ===== Pull statsFor + helpers from pure_simplicial_compute.wl =====
   The Get'd script also runs a per-p sampling loop on load; suppress it
   by passing pListOverride = {} so the loop is a no-op. Definitions
   (oneSkeleton, statsFor, etc.) persist after Block returns because
   Block scopes only the OwnValues of the listed symbols. *)
Block[{pListOverride = {}, sampleSizeOverride = 0,
       useParallelOverride = False},
  Get[FileNameJoin[{scriptDir, "pure_simplicial_compute.wl"}]]];

(* ===== Cells + expected iso-class counts (validation gates) ===== *)
defaultCells = {{2, 4}, {2, 5}, {2, 6}, {3, 4}, {3, 5}};
expectedIsoCounts = <|
  {2, 4} -> 11, {2, 5} -> 26, {2, 6} -> 68,
  {3, 4} -> 66, {3, 5} -> 445|>;

parseEnvCells[s_String] := Module[{pairs},
  pairs = StringSplit[StringTrim[s], ";"];
  pairs = StringSplit[#, ","] & /@ pairs;
  ToExpression /@ # & /@ pairs];

resolvedCells = Which[
  StringQ[Environment["COMB_TRUTH_CELLS"]] &&
    StringLength[Environment["COMB_TRUTH_CELLS"]] > 0,
    parseEnvCells[Environment["COMB_TRUTH_CELLS"]],
  True, defaultCells];

forceRecompute = With[{e = Environment["COMB_FORCE"]},
  StringQ[e] && e === "1"];

(* ===== Pipeline + parallelism env knobs (added 2026-05-13 Phase 4b) =====
   COMB_TRUTH_PIPELINE selects which enumerator: cheap | bliss | mckay.
     default = cheap (matches original behavior; battle-tested).
   COMB_TRUTH_PARALLEL controls subkernel use: true | false.
     default = true. Set to false for memory-constrained cells (e.g. p=4)
     where ~14 subkernels would multiply working-set memory past 32 GB.
   When pipeline != cheap, the output filename gets a `_<pipeline>` tag
   so cheap and McKay runs of the same cell coexist for cross-validation. *)
pipelineName = With[{e = Environment["COMB_TRUTH_PIPELINE"]},
  If[StringQ[e] && StringLength[e] > 0, ToLowerCase[StringTrim[e]],
    "cheap"]];
pipelineFn = Switch[pipelineName,
  "cheap", streamingEnumeratePure,
  "bliss", streamingEnumeratePureBLISS,
  "mckay", streamingEnumeratePureMcKay,
  _, Print["    ERROR: unknown COMB_TRUTH_PIPELINE: ", pipelineName,
       " (expected cheap | bliss | mckay)"]; Abort[]];
parallelMode = With[{e = Environment["COMB_TRUTH_PARALLEL"]},
  If[StringQ[e] && StringLength[e] > 0,
    ToLowerCase[StringTrim[e]] =!= "false",
    True]];

(* ===== Provenance ===== *)
ecGravVersion = "1.0.0";  (* vendored at ECGrav/ECGrav-1.0.0/ *)
enumeratorVersion = Module[{res, sha},
  res = Quiet @ RunProcess[{
    "git", "-C", projectRoot, "rev-parse", "--short", "HEAD"}];
  If[AssociationQ[res] && res["ExitCode"] === 0,
    sha = StringTrim[res["StandardOutput"]];
    "streaming_enumerator.wl@" <> sha,
    "streaming_enumerator.wl@unknown"]];

Print["scriptDir         = ", scriptDir];
Print["outputDir         = ", outputDir];
Print["resolvedCells     = ", resolvedCells];
Print["forceRecompute    = ", forceRecompute];
Print["pipeline          = ", pipelineName];
Print["parallelMode      = ", parallelMode];
Print["ecGravVersion     = ", ecGravVersion];
Print["enumeratorVersion = ", enumeratorVersion];

(* ===== Per-cell pipeline =====
   Non-cheap pipelines get a tagged filename so cheap and McKay runs of
   the same cell can coexist for cross-validation. *)
truthFile[p_Integer, q_Integer] := FileNameJoin[{outputDir,
  "p" <> ToString[p] <> "q" <> ToString[q] <> "_truth"
    <> If[pipelineName === "cheap", "", "_" <> pipelineName]
    <> ".wxf"}];

statsHeaders = {"numV", "aut", "autF", "connected",
  "num1VConnComps", "num2VConnComps", "largestCompRatio",
  "num2PathConnComps", "num3PathConnComps",
  "Betti1", "Betti2", "Betti3"};

exportWxfAtomic[path_String, expr_] := Module[{tmp, res},
  tmp = path <> ".tmp";
  If[FileExistsQ[tmp], DeleteFile[tmp]];
  Export[tmp, expr, "WXF"];
  If[!FileExistsQ[tmp],
    Print["    ERROR: tmp not written: ", tmp]; Abort[]];
  If[FileExistsQ[path], DeleteFile[path]];
  res = RenameFile[tmp, path];
  If[res === $Failed,
    Print["    ERROR: rename failed ", tmp, " -> ", path]; Abort[]]];

processCell[{p_Integer, q_Integer}] := Module[
  {outFile, expectedIso, sr, wallSec, peakMemMB, isoReps, nIso,
   complexEntries, piV, piF, piU, statsTime, payload, vWeights, fWeights},

  outFile = truthFile[p, q];
  expectedIso = Lookup[expectedIsoCounts, Key[{p, q}], Missing[]];

  Print[""];
  Print["====================================="];
  Print["(p, q) = (", p, ", ", q, ")  -->  ", FileNameTake[outFile]];
  If[!MissingQ[expectedIso],
    Print["  expected |iso|: ", expectedIso],
    Print["  expected |iso|: (no gate registered for this cell)"]];

  If[FileExistsQ[outFile] && FileByteCount[outFile] > 0 && !forceRecompute,
    Print["  WXF already exists (", Round[FileByteCount[outFile]/1024., 0.1],
      " KB), skipping. Set COMB_FORCE=1 to override."];
    Return[]];

  (* ----- Streaming enumeration ----- *)
  ClearSystemCache[];
  {wallSec, sr} = AbsoluteTiming[
    pipelineFn[p, q, Parallel -> parallelMode]];
  peakMemMB = N[MaxMemoryUsed[] / 2.0^20];

  isoReps = sr["isoReps"];
  nIso = Length[isoReps];

  Print["  streaming done in ", Round[wallSec, 0.01], "s,",
    "   peak mem ", Round[peakMemMB, 0.1], " MB"];
  Print["  |isoReps|     = ", nIso];
  Print["  totalEmitted  = ", sr["totalEmitted"]];
  Print["  numBuckets    = ", sr["numBuckets"]];

  (* ----- Validation gate ----- *)
  If[!MissingQ[expectedIso],
    If[nIso =!= expectedIso,
      Print["  *** FAIL: |isoReps| ", nIso,
            " != expected ", expectedIso, " ***"];
      Abort[],
      Print["  ok: iso-class count matches expected ", expectedIso]]];

  (* ----- Per-iso-class stats ----- *)
  Print["  computing 12-stat row for ", nIso, " iso classes ..."];
  {statsTime, complexEntries} = AbsoluteTiming[
    Table[
      With[{cmplx = isoReps[[i]]},
        Module[{statsAssoc},
          statsAssoc = AssociationThread[
            statsHeaders -> statsFor[cmplx, p]];
          <|"facets" -> cmplx,
            "aut"   -> statsAssoc["aut"],
            "autF"  -> statsAssoc["autF"],
            "nV"    -> statsAssoc["numV"],
            "stats" -> statsAssoc|>]],
      {i, nIso}]];
  Print["    stats time  : ", Round[statsTime, 0.01], "s"];

  (* ----- Exact distributions over iso classes -----
     π_V(X) ∝ nV(X)! / aut(X)
     π_F(X) ∝ q!     / autF(X)
     π_U(X) ∝ 1
     Use exact rationals for the unnormalized weights, then convert to
     machine reals at the very end. *)
  vWeights = (#["nV"]! / #["aut"]) & /@ complexEntries;
  fWeights = (q! / #["autF"]) & /@ complexEntries;
  piV = N[vWeights / Total[vWeights]];
  piF = N[fWeights / Total[fWeights]];
  piU = ConstantArray[N[1/nIso], nIso];

  (* Sanity: distributions sum to 1 within float tolerance. *)
  MapThread[
    Function[{d, name}, With[{s = Total[d]},
      If[Abs[s - 1.0] > 1.0*^-9,
        Print["    WARNING: ", name, " sum is ", s, " (expected 1.0)"]]]],
    {{piV, piF, piU}, {"piVertex", "piFacet", "piUnlabeled"}}];

  (* ----- Persist ----- *)
  payload = <|
    "p" -> p, "q" -> q,
    "numIsoClasses"     -> nIso,
    "totalFacetLabeled" -> sr["totalEmitted"],
    "numBuckets"        -> sr["numBuckets"],
    "complexes"         -> complexEntries,
    "piVertex"          -> piV,
    "piFacet"           -> piF,
    "piUnlabeled"       -> piU,
    "wallClockSec"      -> wallSec,
    "peakMemMB"         -> peakMemMB,
    "pipeline"          -> pipelineName,
    "parallelMode"      -> parallelMode,
    "ecGravVersion"     -> ecGravVersion,
    "enumeratorVersion" -> enumeratorVersion,
    "createdAt"         -> DateString[]|>;

  exportWxfAtomic[outFile, payload];
  Print["  wrote ", FileNameTake[outFile],
    "  (", Round[FileByteCount[outFile] / 1024., 0.1], " KB)"]];

(* ===== Driver ===== *)
Do[processCell[cell], {cell, resolvedCells}];

Print[""];
Print["====================================="];
Print["Done."];
