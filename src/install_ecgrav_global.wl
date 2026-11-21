(* install_ecgrav_global.wl
   Install the ECGrav checkout that scripts load (see load_ecgrav.wl: the
   shared upstream clone, or COMB_ECGRAV_DIR) as this machine's global
   paclet, replacing any other ECGrav version. This is only for
   notebooks, src/reference/ and the Wolfram MCP server, which use a plain
   Needs["ECGrav`"]. Scripts never use the global paclet.

   Rerun it after tools/dev/update_ecgrav.wl moves the shared clone.

   Note: the installed paclet reports PacletInfo's version string (e.g.
   1.18.0), not the commit; the commit is printed here and written into the
   installed folder as SOURCE_COMMIT.txt. *)

Get[FileNameJoin[{DirectoryName[$InputFileName], "comb_paths.wl"}]];

Module[{env, src, commit, archive, installed},
  env = Environment["COMB_ECGRAV_DIR"];
  src = If[StringQ[env] && StringLength[env] > 0 && env =!= "installed",
    ExpandFileName[env], FileNameJoin[{$CombRoot, "ECGrav-upstream"}]];
  If[!FileExistsQ[FileNameJoin[{src, "PacletInfo.wl"}]],
    Print["install_ecgrav_global: no ECGrav at ", src,
      "; run tools\\dev\\update_ecgrav.wl first"]; Abort[]];
  commit = Quiet @ RunProcess[{"git", "-C", src, "rev-parse", "HEAD"},
    "StandardOutput"];
  commit = If[StringQ[commit], StringTrim[commit], "unknown"];
  archive = CreatePacletArchive[src, $TemporaryDirectory];
  Scan[(Print["uninstalling ECGrav ", #["Version"], " at ", #["Location"]];
      PacletUninstall[#]) &, PacletFind["ECGrav"]];
  installed = PacletInstall[File[archive], ForceVersionInstall -> True];
  DeleteFile[archive];
  Export[FileNameJoin[{installed["Location"], "SOURCE_COMMIT.txt"}],
    "github.com/kassabetre/ECGrav " <> commit <> "\n", "Text"];
  Print["installed ECGrav ", installed["Version"], " (", StringTake[commit, UpTo[7]],
    ") from ", src, " at ", installed["Location"]];
];
