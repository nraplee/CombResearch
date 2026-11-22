(* run_mh_chains.wl -- SHIM (Phase 4 row 3, 2026-11-22).
   The MH driver moved to pipeline/30_mh.wl (same knobs COMB_MH_*, same
   defaults, same output names; header there). This file runs it in the same
   kernel, so the .ps1 launchers and bare runs behave as before. Deleted in
   Phase 5. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "30_mh.wl"}]];
