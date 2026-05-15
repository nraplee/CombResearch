(* probe_p4_cheap.wl
   Phase 4b investigation: does the cheap pipeline reach (4,4)? If so,
   what's the iso class count, the wall-clock, and the peak memory?
   This is the first p=4 enumeration the project has ever attempted
   (beyond IS sampling at (4,10)).

   Run sequentially (Parallel -> False) to get a clean per-kernel memory
   number — that's the unit that matters for the parallel-mode (4,5)
   OOM hypothesis. If sequential (4,4) fits in N MB, parallel-mode (4,5)
   needs roughly k * scaleFactor * N MB where k is the kernel count.

   Aborts cleanly on timeout via TimeConstrained.

   Run:
     wolframscript -file src/probe_p4_cheap.wl
   Override the timeout (seconds, default 1800):
     COMB_PROBE_TIMEOUT=600 wolframscript -file src/probe_p4_cheap.wl
*)

scriptDir = If[ValueQ[$InputFileName] && $InputFileName =!= "",
  DirectoryName[$InputFileName], Directory[]];
Get[FileNameJoin[{scriptDir, "streaming_enumerator.wl"}]];

timeoutSec = With[{e = Environment["COMB_PROBE_TIMEOUT"]},
  If[StringQ[e] && StringLength[e] > 0, ToExpression[e], 1800]];

Print["Attempting (4,4) cheap pipeline, sequential mode, timeout = ",
  timeoutSec, " s"];

ClearSystemCache[];
preMem = MemoryInUse[];

result = TimeConstrained[
  AbsoluteTiming[streamingEnumeratePure[4, 4, Parallel -> False]],
  timeoutSec,
  $TimedOut];

If[result === $TimedOut,
  Print["*** TIMED OUT at ", timeoutSec, " s — abort. ***"];
  Print["peakMem so far: ", Round[N[MaxMemoryUsed[]/2.0^20], 0.1], " MB"];
  Abort[]];

{wallSec, r} = result;
peakMB = N[MaxMemoryUsed[] / 2.0^20];
nIso = Length[r["isoReps"]];

Print[""];
Print["==== (4,4) cheap result ===="];
Print["  iso class count : ", nIso];
Print["  totalEmitted    : ", r["totalEmitted"]];
Print["  numBuckets      : ", r["numBuckets"]];
Print["  wall-clock      : ", Round[wallSec, 0.01], " s"];
Print["  peak mem        : ", Round[peakMB, 0.1], " MB"];
Print[""];
Print["Implication for (4,5):"];
Print["  If (4,5) iso count scales ~5-10x (per (3,4)->(3,5) ratio of 6.7x),"];
Print["  expect ~", Round[nIso * 6.7], " iso classes at (4,5)"];
Print["  parallel (k=14) peak mem ~ k * scale * peakMB"];
Print["  with k=14 and 10x scale: ~", Round[14 * 10 * peakMB / 1024., 0.1], " GB"];
Print["  with k=4  and 10x scale: ~", Round[4  * 10 * peakMB / 1024., 0.1], " GB"];
Print["  with k=2  and 10x scale: ~", Round[2  * 10 * peakMB / 1024., 0.1], " GB"];
