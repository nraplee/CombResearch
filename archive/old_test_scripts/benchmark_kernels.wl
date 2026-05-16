(* benchmark_kernels.wl
   Compare global / local / mixed proposal kernels at p=4 q=10 unlabeled.
   Each runs 10k steps + 1k burn-in. Reports accept rate, τ_int(numV),
   ESS, effective samples per second, and stable-mean E[numV]. *)

Needs["ECGrav`"];
$smokeTestSkip = True;
Get["src/sampler_mh.wl"];

Print["benchmarking proposal kernels at p=4 q=10, target=unlabeled, 10k+1k"];
Print["----------------------------------------------------------------------"];

Do[Module[{t, res, trace, ac},
  t = First @ AbsoluteTiming[
    res = runMHChain[4, 10, "unlabeled", 10000, burnIn -> 1000,
      kernel -> kn, verbose -> False]];
  trace = numActive /@ res["trace"];
  ac = integratedAutocorrTime[trace];
  Print["kernel=", kn];
  Print["  wall-clock     : ", N[t], " s"];
  Print["  accept rate    : ", N[res["acceptRate"]]];
  Print["  τ_int(numV)    : ", N[ac["tau"]]];
  Print["  ESS            : ", Round[ac["ess"]], " / ", Length[trace]];
  Print["  ESS / sec      : ", N[ac["ess"] / t]];
  Print["  E[numV]        : ", N[Mean[trace]],
    " ± ", N[StandardDeviation[trace]]];
  Print["  Δm distribution: ", res["deltaNumVCounts"]];
  Print[""]],
  {kn, {"global", "local", "mixed"}}];
