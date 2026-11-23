(* render_ecgrav_compare.wl -- SHIM (Phase 4 row 7, 2026-11-22).
   The MH vs ECGrav RandomFacetLabeled figure moved to pipeline/60_figures.wl, job "ecgrav_compare" (header there).
   Same knobs, inputs and outputs as before. Deleted in Phase 5. *)

$CombFigureJob = "ecgrav_compare";
Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "60_figures.wl"}]];
