(* lib_stats.wl -- SHIM (Phase 4 row 2, 2026-11-22).
   The per-complex statistics moved to the CombResearch package
   (CombResearch/Kernel/Subpackages/Statistics.wl), verbatim; the column order
   is unchanged, so existing WXFs stay comparable. This file keeps the old
   Global names working in the same kernel until Phase 5:

     statsFor[c, p]        = PureComplexStatistics[c, p]   (12-column row)
     $CombStatsHeaders     = $PureComplexStatisticNames
     $CombISHeaders        $CombStatsHeaders plus the 3 IS weight columns
                           (pure_simplicial_compute.wl stats WXFs; moves with
                           ISSampler.wl)
     oneSkeleton, kPathComps, simplicesOfDim, boundaryMatrix, bettiNumber
                           the helpers

   Loads ECGrav and the package through load_combresearch.wl.

   Subkernels: call combLoadCombResearchOnKernels[] (not only
   combLoadECGravOnKernels[]) before DistributeDefinitions[statsFor], so the
   package is loaded there too. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "load_combresearch.wl"}]];

$CombStatsHeaders = $PureComplexStatisticNames;

$CombISHeaders = Join[$CombStatsHeaders, {"wVertex", "wUnlabeled", "wFacet"}];

ClearAll[oneSkeleton, kPathComps, simplicesOfDim, boundaryMatrix, bettiNumber, statsFor];
oneSkeleton[c_List] := CombResearch`Private`oneSkeleton[c];
kPathComps[c_List, k_Integer] := CombResearch`Private`kPathComps[c, k];
simplicesOfDim[c_List, k_Integer] := CombResearch`Private`simplicesOfDim[c, k];
boundaryMatrix[ks_List, km1s_List] := CombResearch`Private`boundaryMatrix[ks, km1s];
bettiNumber[c_List, k_Integer] := CombResearch`Private`bettiNumber[c, k];
statsFor[c_List, p_Integer] := PureComplexStatistics[c, p];
