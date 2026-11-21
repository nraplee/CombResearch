(* sections/samplecols.wl
   Freezes a column summary of EVERY sample WXF in the store, as it is today:
     p*_mh_*.wxf             MH chains (src/run_mh_chains.wl, run_q10_*.ps1)
     p*_ecg*_*.wxf           ECGrav samplers (src/run_ecgrav_samplers.wl)
     p3q5_mh_vertex.2026-05-17.wxf.bak   post-fix (3,5) vertex chain behind
                             is_mh_truth_3way_summary.wxf
     q10_pilot_archive/*.wxf 10k-iter q=10 pilots
   Per file: headers, row count, non-blank count, exact integer-column
   totals, largestCompRatio total in row order, value-type counts, classIdx
   total/zero count, embedded scalar metadata (see lib/samplecols.wl).
   Stale pre-fix vertex chains (acceptRate exactly 1.) carry "knownBad". *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "lib", "samplecols.wl"}]];

sampleColsInputs[] := Join[
  goldenGlob["p*_mh_*.wxf"],
  goldenGlob["p*_ecg*_*.wxf"],
  {"p3q5_mh_vertex.2026-05-17.wxf.bak"},
  ("q10_pilot_archive/" <> #) & /@ Sort[FileNameTake /@
    FileNames["*.wxf", FileNameJoin[{$CombDataDir, "q10_pilot_archive"}]]]];

goldenSection["samplecols"] := Module[{inputs, records},
  inputs = sampleColsInputs[];
  records = Association @ Map[
    Function[f, Module[{r},
      r = sampleFileRecord[goldenImport[f]];
      goldenForget[f];  (* ecgexact files are ~100k rows; free each one *)
      f -> r]],
    inputs];
  <|"inputs" -> inputs, "records" -> records|>];
