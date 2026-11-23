(* render_q10_warm_vs_prod.wl -- SHIM (Phase 4 row 7, 2026-11-22).
   The q=10 warm-start vs production grid moved to pipeline/60_figures.wl, job "q10_warm_vs_prod" (header there).
   Same knobs, inputs and outputs as before. Deleted in Phase 5. *)

$CombFigureJob = "q10_warm_vs_prod";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "60_figures.wl"}]];
