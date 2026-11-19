(* install_ecgrav_global.wl
   Install the pinned vendored ECGrav snapshot as this machine's global paclet,
   replacing any other ECGrav version, so notebooks, src/reference/ and the
   Wolfram MCP server (plain Needs["ECGrav`"]) match what scripts load via
   load_ecgrav.wl. Scripts themselves do not need this.

   Env: COMB_ECGRAV_VERSION   snapshot under ECGrav/ (default as in load_ecgrav.wl)

   Note: the installed paclet reports PacletInfo's version string (e.g.
   1.18.0), not the commit; SOURCE_COMMIT.txt is copied in for provenance. *)

Module[{root, ver, src, archive, installed},
  root = ParentDirectory[DirectoryName[$InputFileName]];
  ver = With[{e = Environment["COMB_ECGRAV_VERSION"]},
    If[StringQ[e] && StringLength[e] > 0, e, "1.18.0-474b5c2"]];
  src = FileNameJoin[{root, "ECGrav", "ECGrav-" <> ver}];
  If[!FileExistsQ[FileNameJoin[{src, "PacletInfo.wl"}]],
    Print["install_ecgrav_global: no snapshot at ", src]; Abort[]];
  archive = CreatePacletArchive[src, $TemporaryDirectory];
  Scan[(Print["uninstalling ECGrav ", #["Version"], " at ", #["Location"]];
      PacletUninstall[#]) &, PacletFind["ECGrav"]];
  installed = PacletInstall[File[archive], ForceVersionInstall -> True];
  DeleteFile[archive];
  Print["installed ECGrav ", installed["Version"], " (", ver, ") at ",
    installed["Location"]];
];
