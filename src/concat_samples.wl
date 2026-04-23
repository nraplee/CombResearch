(* concat_samples.wl
   Concatenate per-p sample CSVs from multiple compute runs into a single
   merged CSV per p, and report combined ESS diagnostics.

   By default, for each p in {2,3,4} it discovers every file matching
     data/p{p}q10_*_samples.csv
   except the merged output file itself and any `_merged_` file, validates
   that they share the same 15-column schema, and writes
     data/p{p}q10_merged_samples.csv
   Any row missing a weight column is treated as invalid and the script aborts.

   Usage:
     wolframscript -file src/concat_samples.wl
     wolframscript -file src/concat_samples.wl            (* same *)

   To merge only a specific subset, edit `inputsForP` below or pre-move the
   unwanted CSVs out of data/. The render script can be pointed at the merged
   file by setting sampleSize / sampleTag appropriately in render_all_figures.wl
   (see the "Feeding merged data into the render" note in concat_samples.wl). *)

qVal = 10;
pList = {2, 3, 4};

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
projectRoot = ParentDirectory[scriptDir];
dataDir = FileNameJoin[{projectRoot, "data"}];

mergedFileName[p_] := "p" <> ToString[p] <> "q" <> ToString[qVal] <>
  "_merged_samples.csv";
mergedPath[p_] := FileNameJoin[{dataDir, mergedFileName[p]}];

(* Discover candidate input CSVs for a given p.
   Pattern:  p{p}q10_*_samples.csv
   Excludes: the merged output file itself. *)
inputsForP[p_] := Module[{pattern, matches},
  pattern = "p" <> ToString[p] <> "q" <> ToString[qVal] <> "_*_samples.csv";
  matches = FileNames[pattern, dataDir];
  Select[matches, FileBaseName[#] =!= FileBaseName[mergedFileName[p]] &]];

expectedHeaders = {"numV", "aut", "autF", "connected",
  "num1VConnComps", "num2VConnComps", "largestCompRatio",
  "num2PathConnComps", "num3PathConnComps",
  "Betti1", "Betti2", "Betti3",
  "wVertex", "wUnlabeled", "wFacet"};

loadCSV[path_] := Module[{raw, headers, body},
  raw = Import[path, "CSV"];
  If[raw === $Failed || Length[raw] < 2,
    Print["  ERROR: failed to read or empty: ", path]; Abort[]];
  headers = First[raw];
  body = Rest[raw];
  If[headers =!= expectedHeaders,
    Print["  ERROR: header mismatch in ", FileNameTake[path]];
    Print["    expected: ", expectedHeaders];
    Print["    got     : ", headers];
    Abort[]];
  {headers, body}];

(* ESS on the weight columns.
   wU = column 14 (wUnlabeled), wF = column 15 (wFacet).
   Values stored as strings in the CSV — parse to numbers. *)
parseWeight[x_] := Which[
  x === "" || x === "Missing" || x === Null, 0.,
  NumberQ[x], N[x],
  StringQ[x], N[ToExpression[x]],
  True, 0.];

essOfWeights[ws_] := Module[{w = parseWeight /@ ws, s1, s2},
  s1 = Total[w];
  s2 = Total[w^2];
  If[s2 == 0, 0, N[s1^2 / s2]]];

mergeForP[p_] := Module[{files, parts, allBody, combined, wU, wF, essU, essF, n},
  Print["--- p = ", p, " ---"];
  files = inputsForP[p];
  If[files === {},
    Print["  no inputs found for p=", p, "; skipping"];
    Return[Null]];
  Print["  inputs:"];
  Do[Print["    ", FileNameTake[f], "  (",
    ToString[FileByteCount[f]], " bytes)"], {f, files}];

  parts = loadCSV /@ files;
  allBody = Flatten[parts[[All, 2]], 1];
  n = Length[allBody];
  Print["  merged rows: ", n];

  combined = Prepend[allBody, expectedHeaders];
  Export[mergedPath[p], combined, "CSV"];
  Print["  wrote ", FileNameTake[mergedPath[p]]];

  wU = allBody[[All, 14]];
  wF = allBody[[All, 15]];
  essU = essOfWeights[wU];
  essF = essOfWeights[wF];
  Print["  ESS unlabeled: ", Round[essU], " / ", n,
    " (", ToString[NumberForm[100. essU / n, {4, 3}]], "%)"];
  Print["  ESS facet    : ", Round[essF], " / ", n,
    " (", ToString[NumberForm[100. essF / n, {4, 3}]], "%)"];
  n];

Print["dataDir    = ", dataDir];
Do[mergeForP[p], {p, pList}];
Print["-----------------------------------------"];
Print["Done."];
