(* combresearch.wl
   Loads the CombResearch package (CombResearch/Kernel/CombResearch.wl in the
   checkout this file lives in) after ECGrav (pipeline/common/ecgrav.wl). Scripts get
   the package's algorithms through this file, the same way they get ECGrav
   through ecgrav.wl.

   Idempotent: a second Get is a no-op once the package is loaded from the
   same file.

   Defines:
     $CombResearchKernelFile           the package file loaded
     combLoadCombResearchOnKernels[]   load ECGrav and the package on every
                                       subkernel (call after LaunchKernels[])

   Sets CombResearch`$CombResearchSubkernelSetup to combLoadECGravOnKernels,
   so the package's parallel code loads the same ECGrav checkout on the
   subkernels instead of a globally installed paclet. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "ecgrav.wl"}]];

With[{file = FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName], 2],
    "CombResearch", "Kernel", "CombResearch.wl"}]},
  If[!(ValueQ[$CombResearchKernelFile] && $CombResearchKernelFile === file &&
      MemberQ[$Packages, "CombResearch`"]),
    If[!FileExistsQ[file],
      Print["load_combresearch: no package at ", file]; Abort[]];
    Get[file];
    $CombResearchKernelFile = file]];

CombResearch`$CombResearchSubkernelSetup = combLoadECGravOnKernels;

combLoadCombResearchOnKernels[] := (
  combLoadECGravOnKernels[];
  With[{f = $CombResearchKernelFile},
    ParallelEvaluate[If[!MemberQ[$Packages, "CombResearch`"], Get[f]]]]);
