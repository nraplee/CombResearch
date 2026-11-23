(* pipeline/10_truth.wl
   Truth stage: exact enumeration of the isomorphism classes for each
   requested (p, q), per-class statistics, and the three exact distributions
   over the classes. Replaced src/enumerate_truth.wl (Phase 4; deleted in
   Phase 5: cross-validate a pipeline with COMB_TRUTH_PIPELINE in a scratch COMB_ROOT).

   Output: data/p{p}q{q}_truth.wxf for every pipeline, so a McKay run needs no
   manual rename any more. Schema (unchanged, plus "pipeline" and
   "parallelMode" on every cell):
     <|"p", "q", "numIsoClasses", "totalFacetLabeled", "numBuckets",
       "complexes" -> {<|"facets", "aut", "autF", "nV", "stats"|>, ...},
       "piVertex", "piFacet", "piUnlabeled",   (* normalized, file order *)
       "wallClockSec", "peakMemMB", "pipeline", "parallelMode",
       "ecGravVersion", "enumeratorVersion", "createdAt"|>
   "totalFacetLabeled" is the enumerator's "totalEmitted": the facet-labeled
   count for cheap, fewer (pruned leaves) for McKay. Kept as stored so far.

   Knobs (combSetting, src/lib_config.wl):
     COMB_TRUTH_CELLS     "p,q;p,q"   default: the 9-cell truth grid
     COMB_TRUTH_PIPELINE  auto | cheap | bliss | mckay   default auto
                          (auto = McKay for p >= 4, cheap otherwise)
     COMB_TRUTH_PARALLEL  default true; false for p = 4 memory
     COMB_FORCE=1         overwrite existing files
   Skips cells whose file exists and is non-empty. Gates: every cell of
   $CombTruthIsoCounts must give its known iso-class count, else Exit 1. *)

$pipelineDir = DirectoryName[$InputFileName];
$srcDir = FileNameJoin[{ParentDirectory[$pipelineDir], "src"}];
Get[FileNameJoin[{$srcDir, "load_combresearch.wl"}]];
Get[FileNameJoin[{$srcDir, "comb_paths.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_names.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_config.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_io.wl"}]];

If[!DirectoryQ[$CombDataDir], CreateDirectory[$CombDataDir]];

truthGrid = {{2, 4}, {2, 5}, {2, 6}, {2, 7}, {3, 4}, {3, 5}, {3, 6}, {4, 4}, {4, 5}};
resolvedCells = combSetting["COMB_TRUTH_CELLS", truthGrid, "cells"];
forceRecompute = combSetting["COMB_FORCE", False, "flag"];
pipelineSetting = ToLowerCase[StringTrim[combSetting["COMB_TRUTH_PIPELINE", "auto"]]];
parallelMode = combSetting["COMB_TRUTH_PARALLEL", True, "notFalse"];

If[!MemberQ[{"auto", "cheap", "bliss", "mckay"}, pipelineSetting],
  Print["ERROR: unknown COMB_TRUTH_PIPELINE: ", pipelineSetting,
    " (expected auto | cheap | bliss | mckay)"];
  Exit[2]];
methodOption = If[pipelineSetting === "auto", Automatic, pipelineSetting];

enumeratorVersion = Module[{res},
  res = Quiet @ RunProcess[{"git", "-C", $pipelineDir, "rev-parse", "--short", "HEAD"}];
  "CombResearch/Enumeration.wl@" <>
    If[AssociationQ[res] && res["ExitCode"] === 0, StringTrim[res["StandardOutput"]],
      "unknown"]];

Print["outputDir         = ", $CombDataDir];
Print["resolvedCells     = ", resolvedCells];
Print["forceRecompute    = ", forceRecompute];
Print["pipeline          = ", pipelineSetting];
Print["parallelMode      = ", parallelMode];
Print["ecGravVersion     = ", $CombECGravVersion];
Print["enumeratorVersion = ", enumeratorVersion];

(* One cell: True when written or skipped, False when the gate failed. *)
processCell[{p_Integer, q_Integer}] := Module[
  {outFile, expectedIso, sr, wallSec, peakMemMB, isoReps, nIso, pipelineName,
   complexEntries, piV, piF, piU, statsTime, payload, vWeights, fWeights},

  outFile = combFile["truth", p, q];
  expectedIso = Lookup[$CombTruthIsoCounts, Key[{p, q}], Missing[]];

  Print[""];
  Print["====================================="];
  Print["(p, q) = (", p, ", ", q, ")  -->  ", FileNameTake[outFile]];
  Print["  expected |iso|: ", If[MissingQ[expectedIso], "(no gate for this cell)", expectedIso]];

  If[FileExistsQ[outFile] && FileByteCount[outFile] > 0 && !forceRecompute,
    Print["  WXF already exists (", Round[FileByteCount[outFile]/1024., 0.1],
      " KB), skipping. Set COMB_FORCE=1 to override."];
    Return[True]];

  ClearSystemCache[];
  {wallSec, sr} = AbsoluteTiming[
    EnumerateUnlabeledPureComplexes[p, q, Method -> methodOption,
      "Parallel" -> parallelMode]];
  If[!AssociationQ[sr], Print["  *** FAIL: enumeration returned ", Short[sr]]; Return[False]];
  peakMemMB = N[MaxMemoryUsed[] / 2.0^20];
  pipelineName = ToLowerCase[sr["method"]];
  isoReps = sr["isoReps"];
  nIso = Length[isoReps];

  Print["  ", pipelineName, " enumeration done in ", Round[wallSec, 0.01], "s,",
    "   peak mem ", Round[peakMemMB, 0.1], " MB"];
  Print["  |isoReps|     = ", nIso];
  Print["  totalEmitted  = ", sr["totalEmitted"]];
  Print["  numBuckets    = ", sr["numBuckets"]];

  If[!MissingQ[expectedIso],
    If[nIso =!= expectedIso,
      Print["  *** FAIL: |isoReps| ", nIso, " != expected ", expectedIso, " ***"];
      Return[False],
      Print["  ok: iso-class count matches expected ", expectedIso]]];

  Print["  computing 12-stat row for ", nIso, " iso classes ..."];
  {statsTime, complexEntries} = AbsoluteTiming[
    Table[
      With[{cmplx = isoReps[[i]]},
        Module[{statsAssoc},
          statsAssoc = AssociationThread[$PureComplexStatisticNames -> PureComplexStatistics[cmplx, p]];
          <|"facets" -> cmplx,
            "aut"   -> statsAssoc["aut"],
            "autF"  -> statsAssoc["autF"],
            "nV"    -> statsAssoc["numV"],
            "stats" -> statsAssoc|>]],
      {i, nIso}]];
  Print["    stats time  : ", Round[statsTime, 0.01], "s"];

  (* π_V ∝ nV!/aut, π_F ∝ q!/autF, π_U ∝ 1: exact rationals, then reals. *)
  vWeights = (#["nV"]! / #["aut"]) & /@ complexEntries;
  fWeights = (q! / #["autF"]) & /@ complexEntries;
  piV = N[vWeights / Total[vWeights]];
  piF = N[fWeights / Total[fWeights]];
  piU = ConstantArray[N[1/nIso], nIso];
  MapThread[
    Function[{d, name}, With[{s = Total[d]},
      If[Abs[s - 1.0] > 1.0*^-9,
        Print["    WARNING: ", name, " sum is ", s, " (expected 1.0)"]]]],
    {{piV, piF, piU}, {"piVertex", "piFacet", "piUnlabeled"}}];

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
    "ecGravVersion"     -> $CombECGravVersion,
    "enumeratorVersion" -> enumeratorVersion,
    "createdAt"         -> DateString[]|>;

  exportWxfAtomic[outFile, payload, <|"pipeline" -> pipelineName|>];
  Print["  wrote ", FileNameTake[outFile],
    "  (", Round[FileByteCount[outFile] / 1024., 0.1], " KB)"];
  True];

results = processCell /@ resolvedCells;

Print[""];
Print["====================================="];
If[AllTrue[results, TrueQ],
  Print["Done."],
  Print["FAILED: ", Pick[resolvedCells, TrueQ /@ results, False]]; Exit[1]];
