(* validate_mh_vs_truth.wl -- SHIM (Phase 4 row 6, 2026-11-22).
   Sample-vs-truth validation (COMB_VAL_SOURCE) moved to pipeline/50_validate.wl, job "samples" (header there).
   Same knobs, inputs and output as before. Deleted in Phase 5. *)

$CombValidateJob = "samples";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "50_validate.wl"}]];
