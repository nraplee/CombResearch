(* Per-p wrapper for pure_simplicial_compute.wl, p=4 only.
   Sample count is read from env var COMB_N (e.g. `$env:COMB_N = 2000`);
   falls back to 500000 if unset. ParallelMap on. *)
pListOverride       = {4};
useParallelOverride = True;
If[!ValueQ[sampleSizeOverride],
  With[{envN = Environment["COMB_N"]},
    sampleSizeOverride = If[StringQ[envN] && StringLength[envN] > 0,
      ToExpression[envN], 500000]]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "pure_simplicial_compute.wl"}]];
