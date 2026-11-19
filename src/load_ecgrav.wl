(* load_ecgrav.wl
   The single entry point for ECGrav in this repo. Every script and library
   file loads ECGrav through this file, never through a bare Needs, so the
   master kernel and all subkernels run the same vendored snapshot.

   Loads ECGrav/ECGrav-<version>/Kernel/ECGrav.wl directly with Get,
   bypassing the paclet system. Why: the vendored PacletInfo declares
   WolframVersion -> "15.0+", which the paclet system filters out on older
   kernels (Needs then silently falls back to whatever is installed), and a
   globally installed paclet can drift from the pinned snapshot.

   Idempotent: a second Get of this file with the same version is a no-op,
   so library files (sampler_mh.wl, streaming_enumerator*.wl) can load it
   unconditionally.

   Subkernels: call combLoadECGravOnKernels[] after LaunchKernels[] instead
   of ParallelEvaluate[Needs["ECGrav`"]], which would load the installed
   paclet on each subkernel.

   Env:
     COMB_ECGRAV_VERSION   vendored snapshot to load (default
                           "1.18.0-474b5c2", upstream main @ 474b5c2).
                           "1.17.0" reproduces Phase 5a, "1.0.0" Phase 4.
                           "installed" = plain Needs["ECGrav`"].

   Defines $CombECGravVersion (string, for payload provenance) and
   $CombECGravKernelFile (path, or None in "installed" mode). *)

Module[{here, ver, dir, kernelFile},
  here = If[ValueQ[$InputFileName] && $InputFileName =!= "",
    DirectoryName[$InputFileName], Directory[]];
  ver = With[{e = Environment["COMB_ECGRAV_VERSION"]},
    If[StringQ[e] && StringLength[e] > 0, e, "1.18.0-474b5c2"]];
  Which[
    ValueQ[$CombECGravVersion] && $CombECGravVersion === ver,
      Null,
    ver === "installed",
      Needs["ECGrav`"];
      $CombECGravKernelFile = None;
      $CombECGravVersion = "installed",
    True,
      dir = FileNameJoin[{ParentDirectory[here], "ECGrav", "ECGrav-" <> ver}];
      kernelFile = FileNameJoin[{dir, "Kernel", "ECGrav.wl"}];
      If[!FileExistsQ[kernelFile],
        Print["load_ecgrav: no vendored ECGrav at ", kernelFile]; Abort[]];
      If[MemberQ[$Packages, "ECGrav`"],
        Print["load_ecgrav: WARNING ECGrav` already loaded; ",
          "reloading from ", dir]];
      Get[kernelFile];
      $CombECGravKernelFile = kernelFile;
      $CombECGravVersion = ver;
      Print["ECGrav loaded: ", $CombECGravVersion]];
];

combLoadECGravOnKernels[] := If[$CombECGravKernelFile === None,
  ParallelEvaluate[Needs["ECGrav`"]],
  With[{f = $CombECGravKernelFile},
    ParallelEvaluate[If[!MemberQ[$Packages, "ECGrav`"], Get[f]]]]];
