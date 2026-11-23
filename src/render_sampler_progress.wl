(* render_sampler_progress.wl -- SHIM (Phase 4 row 7, 2026-11-22).
   The MH progress figure moved to pipeline/60_figures.wl, job "sampler_progress" (header there).
   Same knobs, inputs and outputs as before. Deleted in Phase 5. *)

$CombFigureJob = "sampler_progress";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "60_figures.wl"}]];
