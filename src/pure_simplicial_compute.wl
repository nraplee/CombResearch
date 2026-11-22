(* pure_simplicial_compute.wl -- SHIM (Phase 4 row 5, 2026-11-22).
   The q=10 IS driver moved to pipeline/20_is_q10.wl (header there). This
   file Gets it in the same kernel, so the *Override protocol still works:
   run_p{2,3,4}.wl and pure_simplicial_compute_overnight.wl set
   pListOverride, sampleSizeOverride, useParallelOverride (and optionally
   nnFixedOverride, runTagOverride, chunkSizeOverride) before Get-ting this
   file, exactly as before. Same knobs (COMB_NN_FIXED, COMB_RUNTAG,
   COMB_CHUNK), chunk resume and file names. Deleted in Phase 5. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "20_is_q10.wl"}]];
