(* benchmark_samplers.wl
   Wall-clock and effective-samples-per-second comparison: IS direct
   sampling vs MH chain at q=10, p ∈ {2, 3, 4}, target = unlabeled.

   For IS: time to generate 10k samples, then compute per-sample ESS
   contribution from the existing merged data (ESS_total / N_total).
   For MH: time to run 10k MH steps, then compute τ_int(numV) and
   derive ESS = N / (2 τ_int).

   Output: a table of (p, sampler, wall-clock, raw samples/s,
   effective samples/s for unlabeled target). *)

Needs["ECGrav`"];
$smokeTestSkip = True;
Get["src/sampler_mh.wl"];

(* From IS merged data — pre-recorded ESS for unlabeled target.
   See docs/NEXT.md "Final merged ESS" table. *)
isESSTable = <|2 -> {2000000, 667}, 3 -> {12000000, 123}, 4 -> {12000000, 25}|>;

Print["benchmarking samplers at q=10 ..."];
Print[StringRepeat["-", 70]];

results = Table[Module[
  {nIS, tIS, sample, statsIS,
   nMH, tMH, mhRes, mhTrace, mhTau, mhESS,
   isPerSampleESS, mhPerSampleESS,
   isEffPerSec, mhEffPerSec},

  Print["p = ", p, " ..."];

  (* === IS timing (raw sampling only, no statsFor) === *)
  nIS = 10000;
  tIS = First @ AbsoluteTiming[
    sample = RandomVertexLabeledPureSimplicialComplex[{p, 10}, nIS]];
  Print["  IS  : ", nIS, " samples in ", NumberForm[tIS, {5, 2}], "s"];
  isPerSampleESS = N[isESSTable[p][[2]] / isESSTable[p][[1]]];
  isEffPerSec = isPerSampleESS * (nIS / tIS);
  Print["    raw  rate     : ", NumberForm[N[nIS / tIS], {6, 1}], " samples/s"];
  Print["    per-sample ESS: ", NumberForm[isPerSampleESS, {6, 4}],
    "  (from merged ESS=", isESSTable[p][[2]], "/", isESSTable[p][[1]], ")"];
  Print["    effective rate: ", NumberForm[isEffPerSec, {5, 4}], " ESS/s"];

  (* === MH timing === *)
  nMH = 10000;
  tMH = First @ AbsoluteTiming[
    mhRes = runMHChain[p, 10, "unlabeled", nMH, burnIn -> 1000, verbose -> False]];
  mhTrace = numActive /@ mhRes["trace"];
  mhTau = integratedAutocorrTime[mhTrace];
  mhESS = mhTau["ess"];
  mhPerSampleESS = mhESS / nMH;
  mhEffPerSec = mhESS / tMH;
  Print["  MH  : ", nMH, " steps in ", NumberForm[tMH, {5, 2}], "s",
    "  (accept ", NumberForm[mhRes["acceptRate"], {4, 3}], ")"];
  Print["    raw  rate     : ", NumberForm[N[nMH / tMH], {6, 1}], " steps/s"];
  Print["    τ_int(numV)   : ", NumberForm[mhTau["tau"], {5, 1}]];
  Print["    ESS estimate  : ", Round[mhESS], "  per-sample: ",
    NumberForm[mhPerSampleESS, {6, 4}]];
  Print["    effective rate: ", NumberForm[mhEffPerSec, {5, 2}], " ESS/s"];

  Print["  → MH/IS effective-rate ratio: ",
    NumberForm[mhEffPerSec / isEffPerSec, {6, 1}], "×"];
  Print[StringRepeat["-", 70]];

  <|"p" -> p, "tIS" -> tIS, "tMH" -> tMH,
    "isEffPerSec" -> isEffPerSec, "mhEffPerSec" -> mhEffPerSec|>],
  {p, {2, 3, 4}}];

Print[""];
Print["SUMMARY (effective samples / second for unlabeled target):"];
Print["p\tIS\tMH\tspeedup"];
Do[Print[r["p"], "\t",
  NumberForm[r["isEffPerSec"], {5, 4}], "\t",
  NumberForm[r["mhEffPerSec"], {5, 2}], "\t",
  NumberForm[r["mhEffPerSec"] / r["isEffPerSec"], {5, 1}], "×"],
  {r, results}];
