(* run_wl_test.wl
   Checks run.wl's planning and safety rules (Phase 3) in a fresh temporary
   COMB_ROOT that the test creates and deletes. Never touches the store.
   Mostly dry runs; real runs: one q=10 p=2 quick batch and its merge in a
   later pass of the same run.wl, one IS-at-truth-cells job (about 40 s) and
   one check stage (smoke tests, about 3 min).

   Covers the review findings fixed in Phase 3:
     - unknown profile and "all force" exit 2, without starting anything;
     - leftover env: COMB_FORCE (also lower-case comb_force), identity knobs
       (COMB_MH_CELLS, COMB_NN_FIXED) are ignored, tuning knobs win over the
       profile and say so;
     - partial outputs: only the missing cells are run, the job counts as
       done, existing outputs are untouched; a cell with only some IS hists
       is held back without force;
     - a leftover McKay-tagged truth file does not block the truth job;
     - a lock file stops a launch, at plan time;
     - validate with cells: every summary writer is skipped, counts runs;
       validate runs pipeline/50_validate.wl jobs, results tables last;
       figures runs pipeline/60_figures.wl jobs (COMB_FIG_JOB);
       sampler legacyfacet validates legacyfacet;
     - force on a finished q=10 batch is refused;
     - check: the regression is decided after the update, and skipped at run
       time when the current commit has passed;
     - knob values longer than their column are printed whole;
     - status works on a bare store.
   Exit 0 pass, 1 fail.

     wolframscript -file tests\run_wl_test.wl *)

$code = ParentDirectory[DirectoryName[$InputFileName]];

(* The shared ECGrav clone of the store this checkout writes to.
   --git-common-dir is absolute from a worktree, relative from the main
   checkout. Found before the temp root exists, so an early exit leaves
   nothing behind. *)
$ecgDir = Module[{c = StringTrim @ Quiet @ RunProcess[{"git", "-C", $code, "rev-parse",
    "--git-common-dir"}, "StandardOutput"]},
  If[StringQ[Environment["COMB_ECGRAV_DIR"]] && Environment["COMB_ECGRAV_DIR"] =!= "",
    Environment["COMB_ECGRAV_DIR"],
    If[!StringMatchQ[c, RegularExpression["^([A-Za-z]:|/|\\\\).*"]], c = FileNameJoin[{$code, c}]];
    FileNameJoin[{ParentDirectory[ExpandFileName[c]], "ECGrav-upstream"}]]];
If[!FileExistsQ[FileNameJoin[{$ecgDir, "Kernel", "ECGrav.wl"}]],
  Print["run_wl_test: no ECGrav at ", $ecgDir, "; set COMB_ECGRAV_DIR"]; Exit[1]];
(* the commit string the way run.wl and load_ecgrav.wl compute it: git only
   when the folder is itself a repo root *)
$ecgCommit = Module[{top, sha, dirty, sc},
  top = Quiet @ RunProcess[{"git", "-C", $ecgDir, "rev-parse", "--show-toplevel"}, "StandardOutput"];
  If[!StringQ[top] || ExpandFileName[StringTrim[top]] =!= ExpandFileName[$ecgDir],
    sc = FileNameJoin[{$ecgDir, "SOURCE_COMMIT.txt"}];
    If[FileExistsQ[sc], First[StringCases[Import[sc, "Text"], RegularExpression["[0-9a-f]{40}"]], "unknown"],
      "unknown"],
    sha = StringTrim @ RunProcess[{"git", "-C", $ecgDir, "rev-parse", "HEAD"}, "StandardOutput"];
    dirty = StringTrim @ RunProcess[{"git", "-C", $ecgDir, "status", "--porcelain",
      "--untracked-files=no"}, "StandardOutput"];
    If[dirty =!= "", sha <> "-dirty", sha]]];

$root = FileNameJoin[{$TemporaryDirectory, "comb_runwl_test_" <> ToString[RandomInteger[10^9]]}];
CreateDirectory[$root];
SetEnvironment["COMB_ROOT" -> $root];
If[CheckAbort[Get[FileNameJoin[{$code, "src", "lib_names.wl"}]]; True, False] =!= True ||
    !StringStartsQ[$CombDataDir, $root],
  Print["run_wl_test: could not set up the temp root"];
  DeleteDirectory[$root, DeleteContents -> True]; Exit[1]];

$fail = 0;
check[label_, got_, want_] := If[got === want, Print["ok   ", label],
  $fail++; Print["FAIL ", label, ": got ", InputForm[got], ", want ", InputForm[want]]];
has[label_, out_, s_] := check[label, StringContainsQ[out, s], True];
hasNot[label_, out_, s_] := check[label <> " (absent)", StringContainsQ[out, s], False];
(* a dry-run line "  <action> <label> <reason>" *)
line[action_, label_] := RegularExpression["(?m)^  " <> action <> "[ ]+" <> label];
knob[name_, value_] := RegularExpression["(?m)^[ ]+" <> name <> "[ ]+= " <> value <> "[ ]"];

runwl[args_List, extraEnv_ : <||>] := Module[{env, r},
  env = Join[KeySelect[Association[GetEnvironment[]], !StringStartsQ[ToUpperCase[#], "COMB_"] &],
    <|"COMB_ROOT" -> $root, "COMB_ECGRAV_DIR" -> $ecgDir|>, extraEnv];
  r = RunProcess[Join[{"wolframscript", "-file", FileNameJoin[{$code, "run.wl"}]}, args], All, "",
    ProcessEnvironment -> env, ProcessDirectory -> $code];
  <|"code" -> r["ExitCode"], "out" -> r["StandardOutput"] <> r["StandardError"]|>];
touch[f_, expr_ : <|"fake" -> True|>] := (If[!DirectoryQ[DirectoryName[f]], CreateDirectory[DirectoryName[f]]];
  Export[f, expr, "WXF"]);

CheckAbort[

(* ----- command line ----- *)
r = runwl[{"mh", "profile", "papr", "dryrun"}];
check["unknown profile exits 2", r["code"], 2];
has["unknown profile message", r["out"], "unknown profile papr"];
(* with dryrun too, so a broken guard could not start real jobs *)
r = runwl[{"mh", "cells", "35", "dryrun"}];
check["malformed cells word exits 2", r["code"], 2];
r = runwl[{"ecgrav", "sampler", "exat", "dryrun"}];
check["unknown sampler word exits 2", r["code"], 2];
r = runwl[{"all", "force", "dryrun"}];
check["all force exits 2", r["code"], 2];
has["all force message", r["out"], "never to all"];

(* ----- status on a bare store ----- *)
r = runwl[{"status"}];
check["status exit 0", r["code"], 0];
has["status report", r["out"], "store report"];

(* ----- leftover env ----- *)
r = runwl[{"mh", "profile", "quick", "cells", "2,4", "targets", "facet", "dryrun"},
  <|"COMB_FORCE" -> "1", "COMB_MH_CELLS" -> "9,9", "COMB_MH_NUMITER" -> "777"|>];
has["leftover identity/force warned as ignored", r["out"], "ignored (run.wl sets these per job"];
has["identity knob keeps the job's cell", r["out"], knob["COMB_MH_CELLS", "2,4"]];
has["mh job runs pipeline/30_mh.wl", r["out"], "pipeline/30_mh.wl"];
hasNot["no COMB_FORCE knob without the force word", r["out"], knob["COMB_FORCE", "1"]];
has["tuning knob from env wins over profile", r["out"], knob["COMB_MH_NUMITER", "777"]];
has["...and says so", r["out"], "env (overrides profile quick)"];
(* Windows env names are case-insensitive *)
r = runwl[{"mh", "profile", "quick", "cells", "2,4", "targets", "facet", "dryrun"},
  <|"comb_force" -> "1", "Comb_Mh_Cells" -> "9,9"|>];
has["lower-case comb_force/identity warned as ignored", r["out"], "ignored (run.wl sets these per job"];
has["lower-case identity knob does not change the cell", r["out"], knob["COMB_MH_CELLS", "2,4"]];
r = runwl[{"is", "profile", "quick", "cells", "2,10", "dryrun"}, <|"COMB_NN_FIXED" -> "7"|>];
has["COMB_NN_FIXED is an identity knob (in the ignored warning)", r["out"],
  RegularExpression["(?m)^WARNING: ignored .*COMB_NN_FIXED=7"]];
hasNot["COMB_NN_FIXED not passed as a profile override", r["out"],
  RegularExpression["(?m)^WARNING: COMB_. variables in this shell .*COMB_NN_FIXED"]];
has["...the batch keeps its planned file name", r["out"], line["run", "is q=10 p=2 quick"]];
has["merge job planned after the batch", r["out"], line["skip", "is merge q=10 p=2"]];
has["...waiting for its batch", r["out"], "inputs missing: p2q10_n2000_quick_stats.wxf"];
has["...with the declared batch list", r["out"], knob["COMB_IS_MERGE_STEMS", "p2q10_n2000_quick"]];
hasNot["dry run plans no later pass", r["out"], "-- pass"];

(* ----- later pass: the merge runs in the same run.wl, after its batch ----- *)
r = runwl[{"is", "profile", "quick", "cells", "2,10"}];
check["later pass: real run exits 0", r["code"], 0];
has["later pass: batch done first", r["out"], "done   is q=10 p=2 quick"];
has["later pass: pass 2 announced", r["out"], "-- pass 2: inputs written by the pass before"];
has["later pass: merge done in the same run", r["out"], "done   is merge q=10 p=2"];
check["later pass: merged stats written", FileExistsQ[combFile["isStats", combMergedStem[2, 10]]], True];
check["later pass: merged complexes written", FileExistsQ[combFile["isComplexes", combMergedStem[2, 10]]], True];
check["later pass: merge lock removed", FileExistsQ[FileNameJoin[{$CombLogsDir, "is_merge_p2.log.lock"}]], False];
r = runwl[{"is", "profile", "quick", "cells", "2,10"}];
check["later pass: rerun exits 0", r["code"], 0];
hasNot["later pass: rerun starts nothing", r["out"], "] start "];
hasNot["later pass: rerun has no pass 2", r["out"], "-- pass"];

(* ----- truth: pipeline/10_truth.wl writes the final name (no McKay rename) ----- *)
touch[combFile["truth", 4, 4, "mckay"]];
r = runwl[{"truth", "profile", "paper", "cells", "4,4", "dryrun"}];
has["mckay leftover does not block the truth job", r["out"], line["run", "truth mckay 4,4"]];
has["truth job runs pipeline/10_truth.wl", r["out"], "pipeline/10_truth.wl"];
has["truth job passes the McKay pipeline", r["out"], knob["COMB_TRUTH_PIPELINE", "mckay"]];
hasNot["no rename hint", r["out"], "rename p4q4_truth_mckay.wxf"];
r = runwl[{"ecgrav", "profile", "quick", "cells", "2,4", "targets", "facet", "sampler", "exact", "dryrun"}];
has["ecgrav job runs pipeline/40_ecgrav.wl", r["out"], "pipeline/40_ecgrav.wl"];

(* ----- lock file ----- *)
touch[combFile["truth", 2, 4]];
lock = FileNameJoin[{$CombLogsDir, "mh_p2q4_facet.log.lock"}];
Put[<|"label" -> "test", "runWlPid" -> -1|>, lock];
r = runwl[{"mh", "profile", "quick", "cells", "2,4", "targets", "facet", "dryrun"}];
has["lock stops a launch", r["out"], "locked: mh_p2q4_facet.log.lock"];
check["a foreign lock is left in place", FileExistsQ[lock], True];
DeleteFile[lock];

(* ----- validate restricted / sampler ----- *)
touch[combFile["mh", 2, 4, "facet"]];
touch[combFile["ecg", 2, 4, "exact", "facet"]];
r = runwl[{"validate", "profile", "quick", "cells", "2,4", "dryrun"}];
Do[has["restricted validate skips " <> l, r["out"], line["skip", l]];
  hasNot["restricted validate runs " <> l, r["out"], line["run", l]],
  {l, {"validate mh", "validate ecgexact", "sampler efficiency", "3-way IS/MH/truth"}}];
has["restricted validate still runs counts", r["out"], line["run", "counts vs truth"]];
has["validate jobs run pipeline/50_validate.wl", r["out"], "pipeline/50_validate.wl"];
has["counts job is COMB_VAL_JOB counts", r["out"], knob["COMB_VAL_JOB", "counts"]];
has["results tables planned", r["out"], line["run", "results tables"]];
r = runwl[{"validate", "profile", "quick", "dryrun"}];
has["summary job names its job", r["out"], knob["COMB_VAL_JOB", "q10_is_vs_mh"]];
r = runwl[{"is", "profile", "quick", "dryrun"}];
has["q=10 histograms run pipeline/22_is_hists.wl", r["out"], "pipeline/22_is_hists.wl"];
r = runwl[{"figures", "profile", "quick", "dryrun"}];
has["figure jobs run pipeline/60_figures.wl", r["out"], "pipeline/60_figures.wl"];
has["q=10 figures job is COMB_FIG_JOB q10_stats", r["out"], knob["COMB_FIG_JOB", "q10_stats"]];
has["uniformity figure planned (no inputs)", r["out"], line["run", "sampler MH uniformity"]];
touch[combFile["ecg", 2, 4, "legacyfacet", "facet"]];
r = runwl[{"validate", "profile", "quick", "sampler", "legacyfacet", "dryrun"}];
has["sampler legacyfacet plans an ecglegacyfacet validation", r["out"], line["(run|skip)", "validate ecglegacyfacet"]];
hasNot["sampler legacyfacet does not validate mh", r["out"], line["(run|skip)", "validate mh"]];

(* ----- force on a finished q=10 batch ----- *)
touch[combFile["isStats", combISStem[2, 10, 2000, None, "quick"]]];
r = runwl[{"is", "profile", "quick", "cells", "2,10", "force", "dryrun"}];
has["force on a finished q=10 batch is refused", r["out"], "force cannot rerun a q=10 batch"];

(* ----- knob values longer than their column (24) are printed whole ----- *)
r = runwl[{"ecgrav", "profile", "paper", "sampler", "mcmc", "targets", "unlabeled", "dryrun"}];
has["long knob value printed whole", r["out"],
  knob["COMB_ECG_CELLS", "2,4;2,5;2,6;2,7;3,4;3,5;3,6;4,4;4,5"]];

(* ----- partial outputs ----- *)
touch[combFile["truth", 3, 4]];
Do[touch[combFile["isHist", 2, 4, t]], {t, {"vertex", "unlabeled", "facet"}}];
(* (4,5): only one hist -> held back without force *)
touch[combFile["isHist", 4, 5, "vertex"]];
r = runwl[{"is", "profile", "quick", "cells", "2,4;3,4", "dryrun"}];
has["partial: plans only the missing cell", r["out"], knob["COMB_IS_CELLS", "3,4"]];
r = runwl[{"is", "profile", "paper", "cells", "4,5", "dryrun"}];
has["partial: a cell with only some hists is held back", r["out"], "cells with only some hists"];
before = FileDate[combFile["isHist", 2, 4, "vertex"], "Modification"];
r = runwl[{"is", "profile", "quick", "cells", "2,4;3,4"}];
check["partial: real run exits 0", r["code"], 0];
has["partial: job done, not FAILED", r["out"], "done   is at truth cells"];
check["partial: (3,4) hists written", AllTrue[{"vertex", "unlabeled", "facet"},
  FileExistsQ[combFile["isHist", 3, 4, #]] &], True];
check["partial: (2,4) hists untouched", FileDate[combFile["isHist", 2, 4, "vertex"], "Modification"], before];
check["partial: lock removed", FileExistsQ[FileNameJoin[{$CombLogsDir, "is_truth_cells.log.lock"}]], False];
check["partial: manifest written", FileExistsQ[combFile["isHist", 3, 4, "vertex"] <> ".manifest.wl"], True];

(* ----- validate warns when one kind of input mixes ECGrav commits ----- *)
fakeManifest[f_, commit_] := Put[<|"backfilled" -> False, "ecgravCommit" -> commit|>, f <> ".manifest.wl"];
Do[touch[combFile["mh", 2, 4, t]], {t, {"unlabeled", "facet"}}];
fakeManifest[combFile["mh", 2, 4, "unlabeled"], "aaaaaaa0000000000000000000000000000000000"];
fakeManifest[combFile["mh", 2, 4, "facet"], "aaaaaaa0000000000000000000000000000000000"];
r = runwl[{"validate", "profile", "quick", "dryrun"}];
hasNot["same commit: no mixed-commit warning", r["out"], "WARNING inputs mix ECGrav commits: mh"];
fakeManifest[combFile["mh", 2, 4, "facet"], "bbbbbbb1111111111111111111111111111111111"];
r = runwl[{"validate", "profile", "quick", "dryrun"}];
has["two commits within the MH chains: warned", r["out"],
  RegularExpression["WARNING inputs mix ECGrav commits: mh: (aaaaaaa \\(1\\), bbbbbbb \\(1\\)|bbbbbbb \\(1\\), aaaaaaa \\(1\\))"]];
hasNot["...not for other families", r["out"], "WARNING inputs mix ECGrav commits: ecgexact"];

(* ----- check: regression decided at run time ----- *)
r = runwl[{"check", "profile", "quick", "dryrun"}];
has["dry run says the regression is decided after the update", r["out"], "decided after the update"];
(* record the current commit as passed: the real check must then skip it at run
   time (the fake truth files would make a real regression fail) *)
If[!DirectoryQ[$CombResultsDir], CreateDirectory[$CombResultsDir]];
Put[<|"commit" -> $ecgCommit, "version" -> "test"|>, FileNameJoin[{$CombResultsDir, "ecgrav_regression_passed.wl"}]];
r = runwl[{"check", "profile", "quick"}];
check["check exits 0", r["code"], 0];
has["regression skipped at run time: commit already passed", r["out"], "already passed"];
hasNot["regression not started", r["out"], "start ECGrav regression"],

Print["run_wl_test: aborted"]; $fail++];

DeleteDirectory[$root, DeleteContents -> True];
If[$fail == 0, Print["PASS"]; Exit[0], Print["FAILED: ", $fail]; Exit[1]];
