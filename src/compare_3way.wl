(* compare_3way.wl -- SHIM (Phase 4 row 6, 2026-11-22).
   The IS / MH / truth comparison moved to pipeline/50_validate.wl, job "3way" (header there).
   Same knobs, inputs and output as before. Deleted in Phase 5. *)

$CombValidateJob = "3way";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "50_validate.wl"}]];
