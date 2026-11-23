(* render_uniformity_check.wl -- SHIM (Phase 4 row 7, 2026-11-22).
   The MH uniformity figure moved to pipeline/60_figures.wl, job "uniformity" (header there).
   Same knobs, inputs and outputs as before. Deleted in Phase 5. *)

$CombFigureJob = "uniformity";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "60_figures.wl"}]];
