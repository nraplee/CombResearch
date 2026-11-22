(* streaming_enumerator_bliss.wl -- SHIM (Phase 4, 2026-11-21).
   The BLISS canonical key and the BLISS enumerator moved to the CombResearch
   package (CombResearch/Kernel/Subpackages/Enumeration.wl). This file keeps
   the old Global names working in the same kernel until Phase 5:

     blissCanonicalKey[complex]        = PureComplexCanonicalKey[complex]
     bipartiteIncidenceGraph[complex]  the vertex-facet incidence graph with
                                       the triangle gadget
     streamingEnumeratePureBLISS[p, q, Parallel -> ...]
         = EnumerateUnlabeledPureComplexes[p, q, Method -> "BLISS", ...] *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "load_combresearch.wl"}]];

ClearAll[blissCanonicalKey, bipartiteIncidenceGraph, streamingEnumeratePureBLISS];
blissCanonicalKey[complex_List] := PureComplexCanonicalKey[complex];
bipartiteIncidenceGraph[complex_List] := CombResearch`Private`bipartiteIncidenceGraph[complex];
Options[streamingEnumeratePureBLISS] = {Parallel -> True};
streamingEnumeratePureBLISS[p_Integer, q_Integer, OptionsPattern[]] :=
  EnumerateUnlabeledPureComplexes[p, q, Method -> "BLISS",
    "Parallel" -> OptionValue[Parallel]];
