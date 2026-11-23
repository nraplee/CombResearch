(* run_tests.wl
   Runs every CombResearch/Tests/*.wlt with TestReport, prints one line per
   file and every failing TestID, exits 1 on any failure.
     wolframscript -file CombResearch\Tests\run_tests.wl
     wolframscript -file CombResearch\Tests\run_tests.wl Enumeration   (one file) *)

$CombResearchTestRoot = ParentDirectory[DirectoryName[$InputFileName]];
Get[FileNameJoin[{$CombResearchTestRoot, "Tests", "TestPrelude.wl"}]];

files = FileNames["*.wlt", FileNameJoin[{$CombResearchTestRoot, "Tests"}]];
With[{only = Rest[$ScriptCommandLine]},
  If[only =!= {}, files = Select[files, MemberQ[only, FileBaseName[#]] &]]];
If[files === {}, Print["run_tests: no .wlt files selected"]; Exit[2]];

allOk = True;
Do[Module[{t, rep, failed},
    Print["running ", FileNameTake[f], " ..."];
    {t, rep} = AbsoluteTiming[TestReport[f, ProgressReporting -> False]];
    failed = Select[Values[rep["TestResults"]], #["Outcome"] =!= "Success" &];
    Print[If[failed === {}, "PASS  ", "FAIL  "], FileNameTake[f], "  ",
      rep["TestsSucceededCount"], "/", Length[rep["TestResults"]], " in ",
      ToString[NumberForm[Round[t, 0.1], {Infinity, 1}]], " s"];
    Do[Print["      failed: ", tr["TestID"], "  got ", Short[tr["ActualOutput"], 3],
        "  expected ", Short[tr["ExpectedOutput"], 3]], {tr, failed}];
    If[failed =!= {}, allOk = False]],
  {f, files}];

Print[If[allOk, "ALL PASS", "FAILURES"]];
Exit[If[allOk, 0, 1]];
