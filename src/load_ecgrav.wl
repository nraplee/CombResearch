(* load_ecgrav.wl
   Load a vendored ECGrav source snapshot directly with Get, bypassing the
   paclet system.

   Why: ECGrav 1.17.0's PacletInfo declares WolframVersion -> "15.0+", so
   on this machine (14.3) PacletDirectoryLoad / PacletInstall silently
   filter it out and Needs["ECGrav`"] falls back to the installed 1.0.0.
   The 1.17.0 source itself runs fine on 14.3 (checked 2026-09-25), so we
   Get Kernel/ECGrav.wl from ECGrav/ECGrav-<version>/. Once ECGrav` is in
   $Packages, later Needs["ECGrav`"] calls (sampler_mh.wl,
   pure_simplicial_compute.wl) are no-ops and see this version.

   Must be loaded BEFORE anything that calls Needs["ECGrav`"].

   Env:
     COMB_ECGRAV_VERSION   vendored snapshot to load (default "1.17.0");
                           "installed" = plain Needs["ECGrav`"].

   Defines $CombECGravVersion (string) for payload provenance. *)

Module[{here, ver, dir, kernelFile},
  here = If[ValueQ[$InputFileName] && $InputFileName =!= "",
    DirectoryName[$InputFileName], Directory[]];
  ver = With[{e = Environment["COMB_ECGRAV_VERSION"]},
    If[StringQ[e] && StringLength[e] > 0, e, "1.17.0"]];
  If[ver === "installed",
    Needs["ECGrav`"];
    $CombECGravVersion = "installed-" <>
      ToString[Quiet @ PacletObject["ECGrav"]["Version"]],
    dir = FileNameJoin[{ParentDirectory[here], "ECGrav", "ECGrav-" <> ver}];
    kernelFile = FileNameJoin[{dir, "Kernel", "ECGrav.wl"}];
    If[!FileExistsQ[kernelFile],
      Print["load_ecgrav: no vendored ECGrav at ", kernelFile]; Abort[]];
    If[MemberQ[$Packages, "ECGrav`"],
      Print["load_ecgrav: WARNING ECGrav` already loaded; ",
        "reloading from ", dir]];
    Get[kernelFile];
    $CombECGravVersion = ver];
  Print["ECGrav loaded: ", $CombECGravVersion];
];
