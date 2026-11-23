(* render_3way.wl -- SHIM (Phase 4 row 7, 2026-11-22).
   The IS / MH / truth grid moved to pipeline/60_figures.wl, job "3way" (header there).
   Same knobs, inputs and outputs as before. Deleted in Phase 5. *)

$CombFigureJob = "3way";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "60_figures.wl"}]];
