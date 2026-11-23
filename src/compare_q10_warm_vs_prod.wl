(* compare_q10_warm_vs_prod.wl -- SHIM (Phase 4 row 6, 2026-11-22).
   The q=10 warm vs production comparison moved to pipeline/50_validate.wl, job "q10_warm_vs_prod" (header there).
   Same knobs, inputs and output as before. Deleted in Phase 5. *)

$CombValidateJob = "q10_warm_vs_prod";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "50_validate.wl"}]];
