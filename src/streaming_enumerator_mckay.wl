(* streaming_enumerator_mckay.wl -- SHIM (Phase 4, 2026-11-21).
   McKay canonical-augmentation enumeration moved to the CombResearch package
   (CombResearch/Kernel/Subpackages/Enumeration.wl). This file keeps the old
   Global names working in the same kernel until Phase 5:

     streamingEnumeratePureMcKay[p, q, Parallel -> ...]
         = EnumerateUnlabeledPureComplexes[p, q, Method -> "McKay", ...]
     canonicalRemovalVSide, isInCanonicalRemovalOrbit  the McKay primitives
   It also loads the BLISS shim, as the old file did. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "streaming_enumerator_bliss.wl"}]];

ClearAll[streamingEnumeratePureMcKay, canonicalRemovalVSide, isInCanonicalRemovalOrbit];
Options[streamingEnumeratePureMcKay] = {Parallel -> True};
streamingEnumeratePureMcKay[p_Integer, q_Integer, OptionsPattern[]] :=
  EnumerateUnlabeledPureComplexes[p, q, Method -> "McKay",
    "Parallel" -> OptionValue[Parallel]];
canonicalRemovalVSide[cmplx_List] := CombResearch`Private`canonicalRemovalVSide[cmplx];
isInCanonicalRemovalOrbit[cmplx_List, c_Integer] :=
  CombResearch`Private`isInCanonicalRemovalOrbit[cmplx, c];
