(* concat_samples.wl -- SHIM (Phase 4 row 5b, 2026-11-22).
   The q=10 batch merge moved to pipeline/21_is_merge.wl (header there).
   Run bare, as before, it merges every p in {2, 3, 4} from every
   p{p}q10_*_stats.wxf on disk; run.wl is runs it per p with the profile's
   batch list instead. Deleted in Phase 5. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "pipeline", "21_is_merge.wl"}]];
