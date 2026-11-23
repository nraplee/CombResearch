(* render_q10_is_vs_mh.wl -- SHIM (Phase 4 row 7, 2026-11-22).
   The q=10 IS vs MH grid moved to pipeline/60_figures.wl, job "q10_is_vs_mh" (header there).
   Same knobs, inputs and outputs as before. Deleted in Phase 5. *)

$CombFigureJob = "q10_is_vs_mh";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "60_figures.wl"}]];
