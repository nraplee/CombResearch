(* render_fig2.wl -- SHIM (Phase 4 row 7, 2026-11-22).
   Figure 2 (p=3, q=3) moved to pipeline/60_figures.wl, job "fig2" (header there).
   Same knobs, inputs and outputs as before. Deleted in Phase 5. *)

$CombFigureJob = "fig2";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "60_figures.wl"}]];
