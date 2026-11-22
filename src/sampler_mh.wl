(* sampler_mh.wl -- SHIM (Phase 4 row 3, 2026-11-22).
   The MH sampler moved to the CombResearch package
   (CombResearch/Kernel/Subpackages/MHSampler.wl, with the full derivation of
   the targets and acceptance ratios). This file keeps the old Global names
   working in the same kernel until Phase 5:

     runMHChain[p, q, target, numIter, burnIn -> ..., thin -> ..., seed -> ...,
       verbose -> ..., kernel -> ..., initNumV -> ...]
         = PureComplexMHChain[...] (same result, same random stream)
     integratedAutocorrTime[x] = IntegratedAutocorrelationTime[x]
     numActive, mhStep, proposeGlobal/Local/Swap/Mixed, initialState,
     warmInitialState, randomSubsetExcluding   the helpers

   As before, Get-ting this file runs a smoke test unless $smokeTestSkip is
   True (every caller in src/ and tests/ sets it). *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "load_combresearch.wl"}]];

ClearAll[runMHChain, integratedAutocorrTime, numActive, mhStep, proposeGlobal,
  proposeLocal, proposeSwap, proposeMixed, initialState, warmInitialState,
  randomSubsetExcluding];
Options[runMHChain] = {burnIn -> 0, thin -> 1, seed -> 12345,
  verbose -> True, kernel -> "global", initNumV -> Automatic};
runMHChain[p_Integer, q_Integer, target_String, numIter_Integer, opts : OptionsPattern[]] :=
  CombResearch`Private`runMHChain[p, q, target, numIter, opts];
integratedAutocorrTime[x_List] := IntegratedAutocorrelationTime[x];
numActive[facets_List] := CombResearch`Private`numActive[facets];
mhStep[args___] := CombResearch`Private`mhStep[args];
proposeGlobal[args___] := CombResearch`Private`proposeGlobal[args];
proposeLocal[args___] := CombResearch`Private`proposeLocal[args];
proposeSwap[args___] := CombResearch`Private`proposeSwap[args];
proposeMixed[args___] := CombResearch`Private`proposeMixed[args];
initialState[args___] := CombResearch`Private`initialState[args];
warmInitialState[args___] := CombResearch`Private`warmInitialState[args];
randomSubsetExcluding[args___] := CombResearch`Private`randomSubsetExcluding[args];

(* =============================================================== *)
(* Smoke test main                                                  *)
(* =============================================================== *)

If[$InputFileName =!= "" && !TrueQ[$smokeTestSkip],
  Module[{result, numVTrace, ac},
    Do[
      Print["==========================================="];
      result = runMHChain[p, 10, "unlabeled", 5000, burnIn -> 1000];
      numVTrace = numActive /@ result["trace"];
      ac = integratedAutocorrTime[numVTrace];
      Print["    τ_int(numV)   : ",
        ToString[NumberForm[ac["tau"], {6, 2}]],
        "  (lagsUsed=", ac["lagsUsed"], ")"];
      Print["    effective N   : ", Round[ac["ess"]],
        " of ", Length[numVTrace]];
      Print["    numV mean/std : ",
        ToString[NumberForm[Mean[N[numVTrace]], {5, 2}]], " / ",
        ToString[NumberForm[StandardDeviation[N[numVTrace]], {5, 2}]]],
      {p, {2, 3, 4}}];
    Print["==========================================="];
    Print["smoke test done."]]];
