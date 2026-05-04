(* scaling_probe.wl
   Phase 1 of docs/PLAN_TRUTH_ENUMERATION.md.

   Benchmarks GenerateAllFacetLabeledPureSimplicialComplexes[{p,q}] and
   ChooseNonIsomorphicSimplicialComplexes for a (p,q) grid, recording
   |allLab|, |iso|, wall-clock per phase, and peak memory per phase.

   Default grid covers the cases the plan calls out. Override via
     gridOverride = {{2,4}};            (* before Get[..] *)
   or by setting env var COMB_PROBE_GRID="2,4;2,5;3,5".

   Per-phase timeout via env var COMB_PROBE_TIMEOUT (seconds, default 1800).
   When a phase times out the case is recorded with status=timeout_* and the
   probe moves on. Each completed case prints a single machine-parseable
   RESULT|... line so the wrapper can parse stdout into a markdown table.
*)

Needs["ECGrav`"];

(* ===== Grid ===== *)
defaultGrid = {
  {2, 5}, {2, 6}, {2, 7}, {2, 8}, {2, 9}, {2, 10},
  {3, 5}, {3, 6},
  {4, 5}, {4, 6}
};

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

(* ===== Probe ===== *)
(* String-formatted rounders. Plain `N[Round[x, 0.001]]` shows binary
   imprecision (e.g. 59.620000000000005); going through ToString with
   PaddedForm yields a clean fixed-decimal string. NumberForm itself
   doesn't render in wolframscript -file mode — it prints as
   `NumberForm[...]` — so we wrap with ToString. *)
roundT[x_?NumericQ]  := StringTrim[ToString[PaddedForm[N[x], {18, 3}]]];
roundT[x_]           := x;
roundMB[x_?NumericQ] := StringTrim[ToString[PaddedForm[N[x], {18, 2}]]];
roundMB[x_]          := x;

probe[{p_Integer, q_Integer}] := Module[
  {tGen, tIso, allLab, iso, nLab, nIso,
   peakGenMB, peakIsoMB, status, res},
  status    = "ok";
  nLab      = "NA"; nIso     = "NA";
  tGen      = "NA"; tIso     = "NA";
  peakGenMB = "NA"; peakIsoMB = "NA";

  Print["[probe] p=", p, " q=", q, " (timeout=", timeoutSec, "s/phase) ..."];
  ClearSystemCache[];

  (* GenerateAll phase *)
  res = TimeConstrained[
    AbsoluteTiming[
      peakGenMB = N[MaxMemoryUsed[
        allLab = GenerateAllFacetLabeledPureSimplicialComplexes[{p, q}]
      ] / 1024.^2];
      Length[allLab]],
    timeoutSec, $TimedOut];
  If[res === $TimedOut,
    status = "timeout_gen";
    Print["  TIMEOUT during GenerateAll after ", timeoutSec, "s"];
    Print["RESULT|p=", p, "|q=", q,
      "|allLab=NA|iso=NA|tGen=NA|tIso=NA",
      "|peakGenMB=NA|peakIsoMB=NA|status=", status];
    Clear[allLab];
    Return[]];
  {tGen, nLab} = res;
  Print["  GenerateAll: ", nLab, " complexes, ", roundT[tGen], "s, peak=",
    roundMB[peakGenMB], " MB"];

  (* ChooseNonIsomorphic phase *)
  res = TimeConstrained[
    AbsoluteTiming[
      peakIsoMB = N[MaxMemoryUsed[
        iso = ChooseNonIsomorphicSimplicialComplexes[allLab]
      ] / 1024.^2];
      Length[iso]],
    timeoutSec, $TimedOut];
  Clear[allLab];
  If[res === $TimedOut,
    status = "timeout_iso";
    Print["  TIMEOUT during ChooseNonIso after ", timeoutSec, "s"];
    Print["RESULT|p=", p, "|q=", q,
      "|allLab=", nLab, "|iso=NA",
      "|tGen=", roundT[tGen], "|tIso=NA",
      "|peakGenMB=", roundMB[peakGenMB], "|peakIsoMB=NA",
      "|status=", status];
    Clear[iso];
    Return[]];
  {tIso, nIso} = res;
  Print["  ChooseNonIso: ", nIso, " iso classes, ", roundT[tIso], "s, peak=",
    roundMB[peakIsoMB], " MB"];
  Clear[iso];

  Print["RESULT|p=", p, "|q=", q,
    "|allLab=", nLab, "|iso=", nIso,
    "|tGen=", roundT[tGen], "|tIso=", roundT[tIso],
    "|peakGenMB=", roundMB[peakGenMB], "|peakIsoMB=", roundMB[peakIsoMB],
    "|status=", status];
];

Print["======= scaling_probe ======="];
Print["grid       : ", resolvedGrid];
Print["timeout    : ", timeoutSec, "s per phase"];
Print["sysMem (MB): ", roundMB[$SystemMemory / 1024.^2]];
Print[""];

Do[probe[pq], {pq, resolvedGrid}];
Print[""];
Print["======= scaling_probe done ======="];
Print["session peak memory (MB): ", roundMB[MaxMemoryUsed[] / 1024.^2]];
