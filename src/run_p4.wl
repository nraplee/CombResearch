(* Per-p wrapper for pure_simplicial_compute.wl, p=4 only.
   Use sampleSizeOverride env / -code prefix to set sample count.
   Default sampleSize = 500000, ParallelMap on. *)
pListOverride       = {4};
useParallelOverride = True;
If[!ValueQ[sampleSizeOverride], sampleSizeOverride = 500000];
Get[FileNameJoin[{DirectoryName[$InputFileName], "pure_simplicial_compute.wl"}]];
