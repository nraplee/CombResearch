(* Per-p wrapper for pure_simplicial_compute.wl, p=3 only.
   Sample count is read from env var COMB_N (e.g. `$env:COMB_N = 2000`);
   falls back to 500000 if unset. ParallelMap on. *)
pListOverride       = {3};
useParallelOverride = True;
Get[FileNameJoin[{DirectoryName[$InputFileName], "lib_config.wl"}]];
If[!ValueQ[sampleSizeOverride],
  sampleSizeOverride = combSetting["COMB_N", 500000, "expr"]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "pure_simplicial_compute.wl"}]];
