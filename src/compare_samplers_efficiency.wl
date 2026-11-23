(* compare_samplers_efficiency.wl -- SHIM (Phase 4 row 6, 2026-11-22).
   The sampler efficiency table moved to pipeline/50_validate.wl, job "efficiency" (header there).
   Same knobs, inputs and output as before. Deleted in Phase 5. *)

$CombValidateJob = "efficiency";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "50_validate.wl"}]];
