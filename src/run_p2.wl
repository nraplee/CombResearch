(* Per-p wrapper for pure_simplicial_compute.wl, p=2 only.
   Use sampleSizeOverride env / -code prefix to set sample count.
   Default sampleSize = 500000, ParallelMap on. *)
pListOverride       = {2};
useParallelOverride = True;
If[!ValueQ[sampleSizeOverride], sampleSizeOverride = 500000];
Get[FileNameJoin[{DirectoryName[$InputFileName], "pure_simplicial_compute.wl"}]];
