(* render_all_figures.wl -- SHIM (Phase 4 row 7, 2026-11-22).
   Figures 3-15 at q=10 moved to pipeline/60_figures.wl, job "q10_stats" (header there).
   Same knobs, inputs and outputs as before. Deleted in Phase 5. *)

$CombFigureJob = "q10_stats";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "60_figures.wl"}]];
