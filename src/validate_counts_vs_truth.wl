(* validate_counts_vs_truth.wl -- SHIM (Phase 4 row 6, 2026-11-22).
   The ECGrav counter check moved to pipeline/50_validate.wl, job "counts" (header there).
   Same knobs, inputs and output as before. Deleted in Phase 5. *)

$CombValidateJob = "counts";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "50_validate.wl"}]];
