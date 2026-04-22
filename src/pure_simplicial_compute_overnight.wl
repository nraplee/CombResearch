(* Overnight wrapper for pure_simplicial_compute.wl.
   Bumps sample size to 500,000 for higher ESS in the reweighted distributions.
   Estimated wall-clock: ~11 hours total (p=2 ~2h, p=3 ~3h, p=4 ~6h).
   Outputs: p{2,3,4}q10_n500000_samples.csv next to this script.

   Run from a shell that will stay alive overnight, e.g.:
     wolframscript -file pure_simplicial_compute_overnight.wl > overnight.log 2>&1
*)

sampleSizeOverride = 500000;
Get[FileNameJoin[{DirectoryName[$InputFileName], "pure_simplicial_compute.wl"}]];
