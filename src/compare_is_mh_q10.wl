(* compare_is_mh_q10.wl -- SHIM (Phase 4 row 6, 2026-11-22).
   The q=10 IS vs MH comparison moved to pipeline/50_validate.wl, job "q10_is_vs_mh" (header there).
   Same knobs, inputs and output as before. Deleted in Phase 5. *)

$CombValidateJob = "q10_is_vs_mh";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "50_validate.wl"}]];
