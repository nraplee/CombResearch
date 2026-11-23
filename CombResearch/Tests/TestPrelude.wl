(* ::Package:: *)

(* Shared setup for the CombResearch .wlt suite (ECGrav style).
   Loads ECGrav and the package from source:
     - inside the CombResearch repo: pipeline/common/combresearch.wl (ECGrav from the
       shared clone or COMB_ECGRAV_DIR, then this checkout's package);
     - elsewhere: ECGrav from ECGRAV_ROOT (an ECGrav checkout) unless ECGrav`
       is already loaded, then Kernel/CombResearch.wl next to Tests/.
   Under TestReport $InputFileName does not point here, so the root comes
   from $CombResearchTestRoot (set by run_tests.wl) when it is defined. *)

If[!ValueQ[$CombResearchTestRoot],
  $CombResearchTestRoot = ParentDirectory[DirectoryName[$InputFileName]]];

With[{repoLoader = FileNameJoin[{ParentDirectory[$CombResearchTestRoot], "pipeline", "common",
    "combresearch.wl"}], env = Environment["ECGRAV_ROOT"]},
  If[FileExistsQ[repoLoader],
    Get[repoLoader],
    If[!MemberQ[$Packages, "ECGrav`"],
      If[StringQ[env] && FileExistsQ[FileNameJoin[{env, "Kernel", "ECGrav.wl"}]],
        Get[FileNameJoin[{env, "Kernel", "ECGrav.wl"}]],
        Print["TestPrelude: set ECGRAV_ROOT to an ECGrav checkout."]; Abort[]]];
    Get[FileNameJoin[{$CombResearchTestRoot, "Kernel", "CombResearch.wl"}]]]];
