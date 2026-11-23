(* golden_common.wl
   Shared helpers for the golden reference (tests/golden/). Loaded by
   golden_derived.wl and by every section file in tests/golden/sections/.

   Golden data is read from $CombDataDir (the shared store, or a scratch
   check root via COMB_ROOT) and the frozen reference is written under the
   CODE checkout ($CombCodeRoot/tests/golden/derived), never through
   $CombRoot.

   Section contract (tests/golden/sections/<name>.wl):
     goldenSection["<name>"] := <|
       "inputs"  -> {"p3q5_truth.wxf", ...},   (* file names in $CombDataDir *)
       "records" -> <|"<key>" -> <|...|>, ...|>  (* small, deterministic *)
     |>
   Records must be reproducible bit-for-bit from the same inputs on the same
   Wolfram build: no RandomVariate without a fixed seed, no wall times, no
   createdAt, no ECGrav loads. Machine reals are fine; they are compared
   with ===.

   Idempotent: a second Get is a no-op. *)

If[!ValueQ[$GoldenDir],
  Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName], 2],
    "pipeline", "common", "paths.wl"}]];
  $GoldenDir = FileNameJoin[{$CombCodeRoot, "tests", "golden"}];
  $GoldenDerivedDir = FileNameJoin[{$GoldenDir, "derived"}];
  $GoldenSectionsDir = FileNameJoin[{$GoldenDir, "sections"}];

  (* Path of a store file by name; aborts if it is missing so a section
     never silently freezes an empty result. *)
  goldenDataFile[name_String] := With[{f = FileNameJoin[{$CombDataDir, name}]},
    If[!FileExistsQ[f], Print["golden: missing input ", f]; Exit[2]]; f];

  (* Cached WXF import of a store file. Only for files a section declares
     in its "inputs". *)
  $goldenImportCache = <||>;
  goldenImport[name_String] := Lookup[$goldenImportCache, name,
    $goldenImportCache[name] = Import[goldenDataFile[name], "WXF"]];
  goldenForget[name_String] := ($goldenImportCache = KeyDrop[$goldenImportCache, name];);

  (* Store file names matching a glob, sorted, for sections whose input set
     is "whatever exists" (e.g. every MH WXF). *)
  goldenGlob[pattern_String] := Sort[FileNameTake /@ FileNames[pattern, $CombDataDir]];

  (* Content hash of any expression (used for compact per-panel ids). *)
  goldenHash[expr_] := Hash[ExportByteArray[expr, "WXF"], "SHA256", "HexString"];
];
