(* scaling_probe_streaming.wl
   Phase 1 (revisited): time the streaming enumerator + online bucketed
   dedupe across the same (p, q) grid the original eager probe ran on.
   Includes cells that previously timed out the eager generator.

   Default grid covers cells where (a) eager succeeded so we can compare
   timings, and (b) eager timed out so we can see if streaming unlocks
   them. Override via env var COMB_PROBE_GRID="p,q;p,q;...".
   Per-phase timeout via COMB_PROBE_TIMEOUT (seconds, default 1800).
*)

Needs["ECGrav`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "streaming_enumerator.wl"}]];

defaultGrid = {
  {2, 4}, {2, 5}, {2, 6}, {2, 7},
  {3, 4}, {3, 5}, {3, 6},
  {4, 5}};

parseEnvGrid[s_String] := Module[{pairs},
  pairs = StringSplit[StringTrim[s], ";"];
  pairs = StringSplit[#, ","] & /@ pairs;
  ToExpression /@ # & /@ pairs];

resolvedGrid = Which[
  ValueQ[gridOverride], gridOverride,
  StringQ[Environment["COMB_PROBE_GRID"]] &&
    StringLength[Environment["COMB_PROBE_GRID"]] > 0,
    parseEnvGrid[Environment["COMB_PROBE_GRID"]],
  True, defaultGrid];

timeoutSec = With[{e = Environment["COMB_PROBE_TIMEOUT"]},
  If[StringQ[e] && StringLength[e] > 0, ToExpression[e], 1800]];

roundT[x_?NumericQ] := StringTrim[ToString[PaddedForm[N[x], {18, 3}]]];
roundT[x_]          := x;
roundMB[x_?NumericQ] := StringTrim[ToString[PaddedForm[N[x], {18, 2}]]];
roundMB[x_]          := x;

probe[{p_Integer, q_Integer}] := Module[
  {tTotal, sr, peakMB, status, res, nIso, nEmitted, nBuckets},
  status   = "ok";
  tTotal   = "NA"; peakMB   = "NA";
  nIso     = "NA"; nEmitted = "NA"; nBuckets = "NA";

  Print["[probe-stream] p=", p, " q=", q,
    " (timeout=", timeoutSec, "s) ..."];
  ClearSystemCache[];

  res = TimeConstrained[
    AbsoluteTiming[
      peakMB = N[MaxMemoryUsed[
        sr = streamingEnumeratePure[p, q]] / 1024.^2];
      sr],
    timeoutSec, $TimedOut];
  If[res === $TimedOut,
    status = "timeout";
    Print["  TIMEOUT after ", timeoutSec, "s"];
    Print["RESULT|p=", p, "|q=", q,
      "|emitted=NA|iso=NA|buckets=NA|tTotal=NA|peakMB=NA|status=", status];
    Return[]];
  {tTotal, sr} = res;
  nEmitted = sr["totalEmitted"];
  nIso     = Length[sr["isoReps"]];
  nBuckets = sr["numBuckets"];
  Print["  emitted=", nEmitted, " iso=", nIso, " buckets=", nBuckets,
    "  ", roundT[tTotal], "s peak=", roundMB[peakMB], " MB"];

  Print["RESULT|p=", p, "|q=", q,
    "|emitted=", nEmitted, "|iso=", nIso, "|buckets=", nBuckets,
    "|tTotal=", roundT[tTotal], "|peakMB=", roundMB[peakMB],
    "|status=", status];
];

Print["======= scaling_probe_streaming ======="];
Print["grid       : ", resolvedGrid];
Print["timeout    : ", timeoutSec, "s per cell"];
Print["sysMem (MB): ", roundMB[$SystemMemory / 1024.^2]];
Print[""];

Do[probe[pq], {pq, resolvedGrid}];
Print[""];
Print["======= scaling_probe_streaming done ======="];
Print["session peak memory (MB): ", roundMB[MaxMemoryUsed[] / 1024.^2]];
