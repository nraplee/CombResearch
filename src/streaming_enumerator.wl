(* streaming_enumerator.wl -- SHIM (Phase 4, 2026-11-21).
   The cheap-key enumerator moved to the CombResearch package
   (CombResearch/Kernel/Subpackages/Enumeration.wl). This file keeps the old
   Global names working in the same kernel until Phase 5 deletes the shims:

     streamingEnumeratePure[p, q, Parallel -> True | False]
         = EnumerateUnlabeledPureComplexes[p, q, Method -> "Cheap", ...]
           (same <|"isoReps", "totalEmitted", "numBuckets"|>, plus "method")
     chooseNonIsoBucketed[list] = ChooseNonIsomorphicPureComplexesBucketed[list]
     canonicalKey[complex]      the cheap invariant key *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "load_combresearch.wl"}]];

ClearAll[streamingEnumeratePure, chooseNonIsoBucketed, canonicalKey];
Options[streamingEnumeratePure] = {Parallel -> True};
streamingEnumeratePure[p_Integer, q_Integer, OptionsPattern[]] :=
  EnumerateUnlabeledPureComplexes[p, q, Method -> "Cheap",
    "Parallel" -> OptionValue[Parallel]];
chooseNonIsoBucketed[allLab_List] := ChooseNonIsomorphicPureComplexesBucketed[allLab];
canonicalKey[complex_List] := CombResearch`Private`canonicalKey[complex];
