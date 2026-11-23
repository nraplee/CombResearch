(* render_truth_overlay.wl -- SHIM (Phase 4 row 7, 2026-11-22).
   The truth / MH overlay panels moved to pipeline/60_figures.wl, job "truth_overlay" (header there).
   Same knobs, inputs and outputs as before. Deleted in Phase 5. *)

$CombFigureJob = "truth_overlay";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "60_figures.wl"}]];
