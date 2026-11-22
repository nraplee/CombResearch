(* pipeline/21_is_merge.wl
   q=10 IS merge step (Phase 4 row 5b). run.wl's is stage runs it once per p,
   after that p's batches, with the batch list from the profile
   (COMB_IS_MERGE_PS = p, COMB_IS_MERGE_STEMS = the batch stems), so the
   merged file is made from a declared list instead of whatever matches the
   glob. src/concat_samples.wl is a shim that Gets this file; run bare it
   still merges every p by the glob, as before.

   Knobs:
     COMB_IS_MERGE_PS     p values (default 2,3,4)
     COMB_IS_MERGE_STEMS  batch stems "p3q10_n500000,p3q10_n1500000_batch2"
                          (default unset: every p{p}q10_*_stats.wxf except
                          the merged file). Inputs are merged in sorted file
                          order, the order the glob gives, so a declared list
                          of the same files reproduces the glob merge.

   Concatenate per-p WXF outputs from multiple compute runs into a single
   merged WXF per p (one for stats, one for complexes), and report combined
   ESS diagnostics.

   For each p in {2,3,4} it discovers every file matching
     data/p{p}q10_*_stats.wxf
   except the merged output file itself. For each matched stats file the
   corresponding complexes file (same stem) must also exist.

   Writes:
     data/p{p}q10_merged_stats.wxf
     data/p{p}q10_merged_complexes.wxf

   Usage:
     wolframscript -file src/concat_samples.wl
*)

qVal = 10;

$pipelineDir = DirectoryName[$InputFileName];
$srcDir = FileNameJoin[{ParentDirectory[$pipelineDir], "src"}];
Get[FileNameJoin[{$srcDir, "comb_paths.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_names.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_config.wl"}]];
Get[FileNameJoin[{$srcDir, "lib_io.wl"}]];
dataDir = $CombDataDir;

pList = combSetting["COMB_IS_MERGE_PS", {2, 3, 4}, "intList"];
mergeStems = combSetting["COMB_IS_MERGE_STEMS", All, "list"];

mergedStatsName[p_]     := combName["isStats", combMergedStem[p, qVal]];
mergedComplexesName[p_] := combName["isComplexes", combMergedStem[p, qVal]];
mergedStatsPath[p_]     := FileNameJoin[{dataDir, mergedStatsName[p]}];
mergedComplexesPath[p_] := FileNameJoin[{dataDir, mergedComplexesName[p]}];

(* Discover candidate stats WXFs for a given p.
   Pattern:  p{p}q10_*_stats.wxf
   Excludes: the merged output itself. *)
statsInputsForP[p_] := Module[{pattern, matches, declared, missing},
  If[mergeStems =!= All,
    declared = Select[mergeStems, StringStartsQ[#, combCell[p, qVal] <> "_"] &];
    declared = FileNameJoin[{dataDir, combName["isStats", #]}] & /@ declared;
    missing = Select[declared, !FileExistsQ[#] &];
    If[missing =!= {},
      Print["  ERROR: declared inputs missing: ", FileNameTake /@ missing]; Exit[1]];
    Return[Sort[declared]]];
  pattern = combISStatsPattern[p, qVal];
  matches = FileNames[pattern, dataDir];
  Select[matches, FileBaseName[#] =!= FileBaseName[mergedStatsName[p]] &]];

(* For a stats file ..._stats.wxf, the sibling complexes file swaps the suffix. *)
complexesSibling[statsPath_] :=
  StringReplace[statsPath, "_stats.wxf" ~~ EndOfString -> "_complexes.wxf"];

expectedHeaders = {"numV", "aut", "autF", "connected",
  "num1VConnComps", "num2VConnComps", "largestCompRatio",
  "num2PathConnComps", "num3PathConnComps",
  "Betti1", "Betti2", "Betti3",
  "wVertex", "wUnlabeled", "wFacet"};

loadStats[path_] := Module[{a},
  a = Import[path, "WXF"];
  If[!AssociationQ[a],
    Print["  ERROR: not an Association: ", path]; Abort[]];
  If[Lookup[a, "headers"] =!= expectedHeaders,
    Print["  ERROR: header mismatch in ", FileNameTake[path]];
    Print["    expected: ", expectedHeaders];
    Print["    got     : ", Lookup[a, "headers"]];
    Abort[]];
  a];

parseWeight[x_] := Which[
  x === "" || x === "Missing" || x === Null || MissingQ[x], 0.,
  NumberQ[x], N[x],
  True, 0.];

essOfWeights[ws_] := Module[{w = parseWeight /@ ws, s1, s2},
  s1 = Total[w]; s2 = Total[w^2];
  If[s2 == 0, 0, N[s1^2 / s2]]];

mergeForP[p_] := Module[{statsFiles, complexFiles, statsAssocs, allRows,
    allComplexes, n, wU, wF, essU, essF, mergedStats, mergedComplexes,
    missingCx, hasAllComplexes},
  Print["--- p = ", p, " ---"];
  statsFiles = statsInputsForP[p];
  If[statsFiles === {},
    Print["  no inputs for p=", p, "; skipping"]; Return[Null]];
  complexFiles    = complexesSibling /@ statsFiles;
  missingCx       = Select[complexFiles, ! FileExistsQ[#] &];
  hasAllComplexes = (missingCx === {});
  If[!hasAllComplexes,
    Print["  WARNING: ", Length[missingCx], " of ",
      Length[complexFiles], " complexes siblings missing — merging stats only"];
    Do[Print["    missing: ", FileNameTake[m]], {m, missingCx}]];

  Print["  inputs:"];
  Do[Print["    ", FileNameTake[f], "  (",
    ToString[FileByteCount[f]], " bytes)"], {f, statsFiles}];

  statsAssocs = loadStats /@ statsFiles;
  allRows     = Join @@ Lookup[statsAssocs, "rows"];
  n = Length[allRows];
  Print["  merged rows: ", n];

  mergedStats = <|
    "headers"   -> expectedHeaders,
    "rows"      -> allRows,
    "p"         -> p,
    "q"         -> qVal,
    "n"         -> n,
    "runTag"    -> "merged",
    "sourceFiles" -> (FileNameTake /@ statsFiles),
    "createdAt" -> DateString[]|>;
  exportWxfAtomic[mergedStatsPath[p], mergedStats,
    <|"inputs" -> (FileNameTake /@ statsFiles)|>];
  Print["  wrote ", FileNameTake[mergedStatsPath[p]]];

  If[hasAllComplexes,
    allComplexes = Join @@ (Lookup[Import[#, "WXF"], "complexes"] & /@ complexFiles);
    If[Length[allComplexes] != n,
      Print["  ERROR: complex count ", Length[allComplexes],
        " != stats rows ", n]; Abort[]];
    mergedComplexes = <|
      "complexes"   -> allComplexes,
      "p"           -> p,
      "q"           -> qVal,
      "n"           -> n,
      "runTag"      -> "merged",
      "sourceFiles" -> (FileNameTake /@ complexFiles),
      "createdAt"   -> DateString[]|>;
    exportWxfAtomic[mergedComplexesPath[p], mergedComplexes,
      <|"inputs" -> (FileNameTake /@ complexFiles)|>];
    Print["  wrote ", FileNameTake[mergedComplexesPath[p]]],
    Print["  skipped ", FileNameTake[mergedComplexesPath[p]],
      " (some inputs lack complexes)"]];

  wU = allRows[[All, 14]];
  wF = allRows[[All, 15]];
  essU = essOfWeights[wU];
  essF = essOfWeights[wF];
  Print["  ESS unlabeled: ", Round[essU], " / ", n,
    " (", ToString[NumberForm[100. essU / n, {4, 3}]], "%)"];
  Print["  ESS facet    : ", Round[essF], " / ", n,
    " (", ToString[NumberForm[100. essF / n, {4, 3}]], "%)"];
  n];

Print["dataDir    = ", dataDir];
Print["pList      = ", pList];
Print["inputs     = ", If[mergeStems === All, "glob (every batch on disk)", mergeStems]];
Do[mergeForP[p], {p, pList}];
Print["-----------------------------------------"];
Print["Done."];
