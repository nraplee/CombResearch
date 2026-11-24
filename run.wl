(* run.wl
   One entry point over the repo's .wl drivers (Phase 3 of
   docs/architecture/implementation-plan.md).

     wolframscript -file run.wl <stage> [option ...]

   Stages, in the order "all" runs them:
     check     update the shared ECGrav clone, run tests\ecgrav_regression.wl
               if that commit has not passed, run the smoke tests, report
               stale outputs
     truth     pipeline/10_truth.wl, one process per truth run of the profile
     is        q=10 IS batches (pipeline/20_is_q10.wl, one process per p and batch),
               their merge per p (pipeline/21_is_merge.wl, the profile's batch
               list; runs once the batches exist),
               IS at the truth cells (23_is_truth_cells.wl), and the
               q=10 numV and statistic histograms (pipeline/22_is_hists.wl)
     mh        pipeline/30_mh.wl, one process per cell and target
     ecgrav    pipeline/40_ecgrav.wl, one process per sampler and target
     validate  counts, MH/ECGrav validation, efficiency and comparison
               summaries; warns when one kind of input (e.g. the MH chains)
               mixes ECGrav commits (guarantee 6, from the manifests)
     figures   pipeline/60_figures.wl, one process per figure job
     status    the stale report only (no runs)
     all       check, truth, is, mh, ecgrav, validate, figures

   Options are plain words (wolframscript drops every script argument from
   the first one that starts with "-"):
     profile quick|paper   run plans and settings from config/cells.wl
                           (default: COMB_PROFILE, else paper)
     cells "3,5;4,5"       only these cells
     targets vertex,facet  only these targets
     sampler exact         ecgrav: only this sampler (exact|mcmc|legacyfacet);
                           validate: only this source (also mh), and no
                           cross-sampler summaries
     jobs N                at most N processes at once (default 4)
     force                 rerun outputs that exist. Only for a named
                           stage, never for "all"
     dryrun                print every job, its reason and its settings
                           with their sources; run nothing

   Skip rule (guarantee 2): a job runs only when one of its outputs is
   missing; outputs that exist are never rerun without force, whatever their
   manifest says. Jobs that write no data file (checks, renders without a
   tracked output) always run. A job whose inputs are missing is skipped
   with that reason; when the stage's other jobs write those inputs, it runs
   in a later pass of the same run (laterPasses).

   Settings (guarantee 3): each job's COMB_* knobs come from the command
   line, else the parent environment (a leftover env var wins over the
   profile, with a warning), else the profile's run plan; anything else is
   left to the driver, which resolves it through config.wl with
   COMB_PROFILE set.

   Logs go to $CombLogsDir under the launchers' names
   (mh_p{p}q{q}_{target}.log, ecg{sampler}_{target}.log,
   compute_p{p}[_{runTag}].log, plus .err), so monitor_mh.ps1 and
   monitor_ecgrav.ps1 work on run.wl runs.

   A job counts as done only if wolframscript exits 0, its log has no
   "$Aborted", and every declared output exists and was written after the
   job started (an Abort[] still exits 0). *)

$code = DirectoryName[$InputFileName];
$src = FileNameJoin[{$code, "pipeline", "common"}];
$args = If[ListQ[$ScriptCommandLine], Rest[$ScriptCommandLine], {}];

usage[msg_String] := (
  If[msg =!= "", Print["run.wl: ", msg]];
  Print["usage: wolframscript -file run.wl <check|truth|is|mh|ecgrav|validate|figures|status|all>"];
  Print["         [profile quick|paper] [cells \"3,5;4,5\"] [targets vertex,facet]"];
  Print["         [sampler exact] [jobs N] [force] [dryrun]"];
  Exit[2]);

$stages = {"check", "truth", "is", "mh", "ecgrav", "validate", "figures"};

(* ----- command line ----- *)
parseArgs[args_List] := Module[{a = args, opts = <||>, stage},
  If[a === {}, usage[""]];
  stage = First[a]; a = Rest[a];
  If[!MemberQ[Join[$stages, {"all", "status"}], stage], usage["unknown stage " <> stage]];
  While[a =!= {},
    Switch[First[a],
      "force" | "dryrun", opts[First[a]] = True; a = Rest[a],
      "profile" | "cells" | "targets" | "sampler" | "jobs",
        If[Length[a] < 2, usage["missing value after " <> First[a]]];
        opts[First[a]] = a[[2]]; a = Drop[a, 2],
      _, usage["unknown option " <> First[a]]]];
  <|"stage" -> stage, "opts" -> opts|>];

$cli = parseArgs[$args];
$stage = $cli["stage"];
$opts = $cli["opts"];
$force = TrueQ[$opts["force"]];
$dryrun = TrueQ[$opts["dryrun"]];
If[$force && $stage === "all", usage["force applies to one named stage, never to all"]];
$maxJobs = If[KeyExistsQ[$opts, "jobs"], ToExpression[$opts["jobs"]], 4];
If[!IntegerQ[$maxJobs] || $maxJobs < 1, usage["jobs needs a positive integer"]];

(* The profile: command line, else COMB_PROFILE, else paper. lib_config
   reads COMB_PROFILE once, so set it before loading. *)
$profileName = Which[
  KeyExistsQ[$opts, "profile"], $opts["profile"],
  StringQ[Environment["COMB_PROFILE"]] && StringTrim[Environment["COMB_PROFILE"]] =!= "",
    StringTrim[Environment["COMB_PROFILE"]],
  True, "paper"];
(* Check the name here: lib_config would Abort[], and wolframscript exits 0
   after an Abort[]. *)
With[{known = Quiet @ Get[FileNameJoin[{$code, "config", "cells.wl"}]]},
  If[!AssociationQ[known], usage["cannot read config/cells.wl"]];
  If[!KeyExistsQ[known, $profileName],
    usage["unknown profile " <> $profileName <> "; known: " <> StringRiffle[Keys[known], ", "]]]];
SetEnvironment["COMB_PROFILE" -> $profileName];

If[CheckAbort[
    Get[FileNameJoin[{$src, "names.wl"}]];
    Get[FileNameJoin[{$src, "config.wl"}]];
    Get[FileNameJoin[{$src, "io.wl"}]]; True, False] =!= True,
  Print["run.wl: loading pipeline/common/*.wl aborted"]; Exit[1]];

(* Pad to n characters without ever cutting the text. *)
pad[s_, n_] := With[{t = ToString[s]}, t <> StringRepeat[" ", Max[1, n - StringLength[t]]]];

$profile = $CombProfileData;
$cliCells = If[KeyExistsQ[$opts, "cells"], combParseCells[$opts["cells"]], All];
$cliTargets = If[KeyExistsQ[$opts, "targets"], combParseList[$opts["targets"]], All];
$cliSampler = Lookup[$opts, "sampler", All];
(* a typo would otherwise match nothing and end "ok" *)
If[$cliCells =!= All && !MatchQ[$cliCells, {{_Integer, _Integer} ..}],
  usage["cells must look like \"3,5;4,5\""]];
If[$cliTargets =!= All && !SubsetQ[{"vertex", "unlabeled", "facet"}, $cliTargets],
  usage["targets are vertex, unlabeled, facet"]];
If[$cliSampler =!= All && !MemberQ[{"exact", "mcmc", "legacyfacet", "mh"}, $cliSampler],
  usage["sampler is exact, mcmc, legacyfacet or mh"]];
pickCells[cells_List] := If[$cliCells === All, cells, Select[cells, MemberQ[$cliCells, #] &]];
pickTargets[ts_List] := If[$cliTargets === All, ts, Select[ts, MemberQ[$cliTargets, #] &]];

(* Leftover COMB_* variables in the caller's environment reach every job.
   Environment names are case-insensitive on Windows (comb_force is
   COMB_FORCE), so names are compared upper-cased; $leftover is keyed by the
   upper-cased name, $leftoverNames keeps the names as the shell has them. *)
$envAll = Association[GetEnvironment[]];
$leftoverNames = Select[Keys[$envAll],
  StringStartsQ[ToUpperCase[#], "COMB_"] &&
    !MemberQ[{"COMB_PROFILE", "COMB_ROOT", "COMB_ECGRAV_DIR"}, ToUpperCase[#]] &&
    StringQ[$envAll[#]] && $envAll[#] =!= "" &];
$leftover = Association[ToUpperCase[#] -> $envAll[#] & /@ $leftoverNames];

(* Never inherited by a job: COMB_FORCE comes only from the force word
   (guarantee 2: never for all), and COMB_MH_OUTDIR would send outputs where
   run.wl does not look. *)
$stripped = {"COMB_FORCE", "COMB_MH_OUTDIR"};

(* Knobs that say which job this is (its cells, targets, sampler, tag, file
   name, ...). run.wl always sets them from the plan and the command line, or
   leaves them unset; a leftover env var cannot change them, or parallel jobs
   would write the same file, or a job would write a name run.wl does not
   check (COMB_NN_FIXED is part of the q=10 IS file name). *)
$identityKnobs = {"COMB_TRUTH_CELLS", "COMB_TRUTH_PIPELINE", "COMB_N", "COMB_RUNTAG", "COMB_IS_PS",
  "COMB_NN_FIXED", "COMB_IS_CELLS", "COMB_MH_CELLS", "COMB_MH_TARGETS", "COMB_MH_TAG",
  "COMB_ECG_SAMPLER", "COMB_ECG_CELLS", "COMB_ECG_TARGETS", "COMB_VAL_SOURCE",
  "COMB_VAL_CELLS", "COMB_VAL_TARGETS", "COMB_EFF_CELLS", "COMB_EFF_TARGETS",
  "COMB_3W_CELLS", "COMB_3W_TARGETS", "COMB_FIG2_N", "COMB_IS_MERGE_PS", "COMB_IS_MERGE_STEMS",
  "COMB_VAL_JOB", "COMB_FIG_JOB"};
$notInherited = Join[$stripped, $identityKnobs];
(* drop them from an environment, whatever their case *)
dropNotInherited[env_Association] := KeySelect[env, !MemberQ[$notInherited, ToUpperCase[#]] &];
(* run.wl plans with the same settings the jobs will see *)
Scan[SetEnvironment[# -> None] &,
  Select[$leftoverNames, MemberQ[$notInherited, ToUpperCase[#]] &]];

(* ----- env values ----- *)
envString[v_] := Which[
  StringQ[v], v,
  MatchQ[v, {{_Integer, _Integer} ..}], StringRiffle[StringRiffle[ToString /@ #, ","] & /@ v, ";"],
  MatchQ[v, {___String}], StringRiffle[v, ","],
  MatchQ[v, {___Integer}], StringRiffle[ToString /@ v, ","],
  v === True, "1",
  True, ToString[v, InputForm]];

(* knobs: name -> {value, source}.
   plan: values from the profile's run plan; a leftover env var wins over
     them (guarantee 3), except for identity knobs.
   fixed: values run.wl sets itself, as {value, source} (source "cli" when it
     comes from a command-line word, "job split" when it is the job's own
     cell/target/sampler/tag). Never overridden by env. *)
resolveKnobs[plan_Association, fixed_Association] := Module[{out = <||>},
  KeyValueMap[Function[{k, v},
    out[k] = Which[
      MemberQ[$identityKnobs, k], {envString[v], "job split"},
      KeyExistsQ[$leftover, k], {$leftover[k], "env (overrides profile " <> $profileName <> ")"},
      True, {envString[v], "profile " <> $profileName}]], plan];
  KeyValueMap[Function[{k, v}, out[k] = {envString[v[[1]]], v[[2]]}], fixed];
  If[$force, out["COMB_FORCE"] = {"1", "cli"}];
  out];
cliOr[v_] := {v, If[$cliCells === All && $cliTargets === All, "job split", "cli"]};

mtime[f_] := If[FileExistsQ[f], AbsoluteTime[FileDate[f, "Modification"]], -Infinity];

(* A job: label, script (relative to $code), knobs, outputs, requires, log. *)
job[label_, script_, knobs_, outputs_, requires_, logStem_] := <|
  "label" -> label, "script" -> script, "knobs" -> knobs,
  "outputs" -> outputs, "requires" -> requires,
  "log" -> FileNameJoin[{$CombLogsDir, logStem <> ".log"}],
  "err" -> FileNameJoin[{$CombLogsDir, logStem <> ".err"}]|>;

(* A job's lock file: there while run.wl runs that job, so a second run.wl
   (another shell) does not start it again. A run.wl killed mid-job leaves
   its locks behind; the next run removes a lock whose run.wl process is
   gone (lockOwnerGone). A lock it cannot read, or from another machine,
   stays: delete it by hand then. *)
lockFile[j_] := j["log"] <> ".lock";

(* True only when the lock's run.wl is surely gone: its PID is not running,
   or now belongs to a program that is not Wolfram (PID reuse). Anything
   unclear (unreadable lock, another host, the OS cannot be asked, a live
   Wolfram process with that PID) keeps the lock. *)
lockOwnerGone[f_] := Module[{l = Quiet @ Get[f], pid, out},
  If[!AssociationQ[l] || !MatchQ[l["runWlPid"], _Integer?Positive], Return[False]];
  If[KeyExistsQ[l, "host"] && l["host"] =!= $MachineName, Return[False]];
  pid = l["runWlPid"];
  If[pid === $ProcessID, Return[False]];
  out = Quiet @ If[$OperatingSystem === "Windows",
    RunProcess[{"tasklist", "/FI", "PID eq " <> ToString[pid], "/FO", "CSV", "/NH"}],
    RunProcess[{"ps", "-p", ToString[pid], "-o", "comm="}]];
  Which[
    !AssociationQ[out] || !StringQ[out["StandardOutput"]], False,
    StringContainsQ[out["StandardOutput"], "wolfram", IgnoreCase -> True], False,
    (* Windows: tasklist ran and listed nothing for the PID; ps: exit 1 = no such PID *)
    $OperatingSystem === "Windows", out["ExitCode"] === 0,
    True, MemberQ[{0, 1}, out["ExitCode"]]]];

(* A lock whose run.wl is gone: removed (a dry run only says so). True when
   the job is no longer locked. *)
clearStaleLock[j_] := With[{f = lockFile[j], pid = Quiet[Get[lockFile[j]]["runWlPid"]]},
  Which[
    !lockOwnerGone[f], False,
    $dryrun, Print["  note  ", FileNameTake[f], " is stale (run.wl pid ", pid,
      " is gone); a real run removes it"]; True,
    True, Quiet[DeleteFile[f]];
      If[FileExistsQ[f], False,
        Print["  note  removed stale ", FileNameTake[f], " (run.wl pid ", pid, " is gone)"]; True]]];

(* {action, reason}. Order: a planned skip reason, a lock, missing inputs,
   then the outputs (guarantee 2). *)
decide[j_Association] := Module[{missingIn, missingOut},
  missingIn = Select[j["requires"], !FileExistsQ[#] &];
  missingOut = Select[j["outputs"], !FileExistsQ[#] &];
  Which[
    KeyExistsQ[j, "skipReason"], {"skip", j["skipReason"]},
    !$force && KeyExistsQ[j, "doneWhen"] && AllTrue[j["doneWhen"], FileExistsQ],
      {"skip", "outputs present as " <> StringRiffle[FileNameTake /@ j["doneWhen"], ", "] <>
        " (rename to the canonical name)"},
    FileExistsQ[lockFile[j]] && !clearStaleLock[j], {"skip", "locked: " <> FileNameTake[lockFile[j]] <>
      " exists (another run.wl on this job? delete it if stale)"},
    missingIn =!= {}, {"skip", "inputs missing: " <>
      StringRiffle[FileNameTake /@ Take[missingIn, UpTo[3]], ", "] <>
      If[Length[missingIn] > 3, " +" <> ToString[Length[missingIn] - 3], ""]},
    j["outputs"] === {}, {"run", "writes no data file"},
    $force && KeyExistsQ[j, "noForce"] && missingOut === {}, {"skip", j["noForce"]},
    $force, {"run", "force"},
    missingOut =!= {}, {"run", ToString[Length[missingOut]] <> " of " <>
      ToString[Length[j["outputs"]]] <> " outputs missing"},
    True, {"skip", "outputs exist"}]];

(* What finishJob checks was rewritten: the job's own "written" list if it
   has one, else the outputs that were missing when it was decided (drivers
   skip outputs that exist), or all outputs with force. *)
expectWritten[j_] := Which[
  KeyExistsQ[j, "written"], j["written"],
  $force, j["outputs"],
  True, Select[j["outputs"], !FileExistsQ[#] &]];

(* ----- stage plans ----- *)
planOf[key_] := Lookup[$profile, key, {}];
truthPath[{p_, q_}] := combFile["truth", p, q];
targets3 = {"unlabeled", "facet", "vertex"};

(* pipeline/10_truth.wl always writes the final _truth.wxf, whatever the
   pipeline (Phase 4), so there is no McKay rename step any more. A leftover
   _truth_<pipeline>.wxf from the old enumerate_truth.wl is ignored. *)
jobsFor["truth"] := Flatten @ Map[Function[r, Module[{cells, pl = r["pipeline"], todo, use},
    cells = pickCells[r["cells"]];
    todo = If[$force, cells, Select[cells, !FileExistsQ[truthPath[#]] &]];
    use = If[todo === {}, cells, todo];
    If[cells === {}, {},
      job["truth " <> pl <> " " <> envString[cells], "pipeline/10_truth.wl",
        resolveKnobs[<|"COMB_TRUTH_PARALLEL" -> If[TrueQ[r["parallel"]], "true", "false"]|>,
          <|"COMB_TRUTH_CELLS" -> cliOr[use], "COMB_TRUTH_PIPELINE" -> {pl, "job split"}|>],
        truthPath /@ use, {}, "truth_" <> pl]]]],
  planOf["truthRuns"]];

jobsFor["is"] := Module[{batches = planOf["isBatches"], out = {}, cellsIS},
  KeyValueMap[Function[{p, bs},
    If[$cliCells === All || MemberQ[$cliCells, {p, 10}],
      Do[With[{runTag = b[[1]], n = b[[2]], chunk = b[[3]],
          stem = combISStem[p, 10, b[[2]], None, b[[1]]]},
        AppendTo[out, job["is q=10 p=" <> ToString[p] <> " " <> If[runTag === "", "batch1", runTag],
          "pipeline/20_is_q10.wl",
          resolveKnobs[<|"COMB_IS_PS" -> ToString[p], "COMB_IS_PAR" -> "1", "COMB_N" -> n,
            "COMB_RUNTAG" -> runTag, "COMB_CHUNK" -> chunk|>, <||>],
          (* skip on the stats file only: batches 1 and 2 were migrated from CSV
             and never had a complexes file *)
          {combFile["isStats", stem]}, {},
          StringDrop[combName["log", "compute", p, If[runTag === "", "", "_" <> runTag]], -4]] ~Join~
          <|"written" -> {combFile["isStats", stem], combFile["isComplexes", stem]},
            (* pipeline/20_is_q10.wl skips a p whose final stats exist and
               has no force knob *)
            "noForce" -> "force cannot rerun a q=10 batch: the driver skips a finished batch; " <>
              "move " <> FileNameTake[combFile["isStats", stem]] <> " away first"|>]],
        {b, bs}];
      (* the merge of this p's batches, from the declared list (Phase 4 row 5b).
         On a fresh store it waits for the batches and runs in a later pass
         of the same run.wl is (laterPasses). force remerges. *)
      With[{stems = Sort[combISStem[p, 10, #[[2]], None, #[[1]]] & /@ bs],
          merged = combMergedStem[p, 10]},
        AppendTo[out, job["is merge q=10 p=" <> ToString[p], "pipeline/21_is_merge.wl",
          resolveKnobs[<||>, <|"COMB_IS_MERGE_PS" -> {{p}, "job split"},
            "COMB_IS_MERGE_STEMS" -> {stems, "job split"}|>],
          {combFile["isStats", merged]}, combFile["isStats", #] & /@ stems,
          "is_merge_p" <> ToString[p]] ~Join~
          (* batches migrated from CSV have no complexes file; the merge then
             writes the merged stats only *)
          <|"written" -> If[AllTrue[stems, FileExistsQ[combFile["isComplexes", #]] &],
            {combFile["isStats", merged], combFile["isComplexes", merged]},
            {combFile["isStats", merged]}]|>]]]], batches];
  cellsIS = pickCells[combSetting["COMB_IS_CELLS", {{3, 5}, {4, 5}}, "cells"]];
  (* The driver works per cell: it rewrites all 3 hists of a cell it runs. A
     cell with only some hists would have its existing ones overwritten, so
     without force it is held back with a reason. *)
  With[{nHave = Function[c, Count[targets3, t_ /; FileExistsQ[combFile["isHist", c[[1]], c[[2]], t]]]],
      hists = Function[cs, Flatten[Table[combFile["isHist", c[[1]], c[[2]], t], {c, cs}, {t, targets3}]]]},
    Module[{partial, todo, j},
      partial = If[$force, {}, Select[cellsIS, 0 < nHave[#] < 3 &]];
      todo = If[$force, cellsIS, Select[cellsIS, nHave[#] == 0 &]];
      If[cellsIS =!= {},
        j = job["is at truth cells " <> envString[cellsIS], "pipeline/23_is_truth_cells.wl",
          resolveKnobs[<||>, <|"COMB_IS_CELLS" -> {If[todo === {}, cellsIS, todo],
            If[$cliCells === All, $CombSettings["COMB_IS_CELLS"]["source"], "cli"]}|>],
          hists[cellsIS], {}, "is_truth_cells"] ~Join~
          <|"written" -> hists[If[todo === {} || $force, cellsIS, todo]]|>;
        If[partial =!= {},
          With[{msg = "cells with only some hists (rerunning would overwrite the others; use force): " <>
              envString[partial]},
            If[todo === {}, j["skipReason"] = msg, Print["  note: ", msg]]]];
        AppendTo[out, j]]]];
  (* q=10 histograms from the merged stats (numV per target, and every
     statistic); here, not in validate, so the q=10 comparisons there always
     see them finished. The driver skips the files that exist. *)
  If[$cliCells === All,
    AppendTo[out, job["q=10 IS histograms", "pipeline/22_is_hists.wl",
      resolveKnobs[<||>, <||>],
      Join[Flatten[Table[combFile["isHist", p, 10, t], {p, {2, 3, 4}}, {t, targets3}]],
        combFile["isStatHists", #, 10] & /@ {2, 3, 4}],
      combFile["isStats", combMergedStem[#, 10]] & /@ {2, 3, 4}, "precompute_is_q10"]]];
  out];

jobsFor["mh"] := Flatten @ Map[Function[g, Module[{tag = Lookup[g, "tag", ""]},
    Table[
      With[{p = c[[1]], q = c[[2]]},
        job["mh " <> combCell[p, q] <> " " <> t <> tag, "pipeline/30_mh.wl",
          resolveKnobs[DeleteMissing @ <|
              "COMB_MH_CELLS" -> {c}, "COMB_MH_TARGETS" -> {t},
              "COMB_MH_NUMITER" -> g["numIter"], "COMB_MH_BURNIN" -> g["burnIn"],
              "COMB_MH_THIN" -> g["thin"], "COMB_MH_SEED" -> g["seed"],
              "COMB_MH_KERNEL" -> g["kernel"], "COMB_MH_TAG" -> tag,
              "COMB_MH_INITNUMV" -> Lookup[g, "initNumV", Missing[]]|>, <||>],
          {combFile["mh", p, q, t, tag]}, {},
          StringDrop[combName["log", "mh", p, q, t, tag], -4]]],
      {c, pickCells[g["cells"]]}, {t, pickTargets[g["targets"]]}]]],
  planOf["mhChains"]];

jobsFor["ecgrav"] := Flatten @ Map[Function[r, If[$cliSampler =!= All && r["sampler"] =!= $cliSampler, {},
    Table[Module[{cells = pickCells[r["cells"]], todo},
        todo = If[$force, cells,
          Select[cells, !FileExistsQ[combFile["ecg", #[[1]], #[[2]], r["sampler"], t]] &]];
        If[cells === {}, Nothing,
          job["ecg" <> r["sampler"] <> " " <> t, "pipeline/40_ecgrav.wl",
            resolveKnobs[DeleteMissing @ <|"COMB_ECG_SAMPLER" -> r["sampler"],
                "COMB_ECG_CELLS" -> If[todo === {}, cells, todo], "COMB_ECG_TARGETS" -> {t},
                "COMB_ECG_N" -> r["n"], "COMB_ECG_BATCH" -> Lookup[r, "batch", Missing[]],
                "COMB_ECG_SEED" -> r["seed"],
                "COMB_ECG_TRACE_STEPS" -> Lookup[r, "traceSteps", Missing[]]|>, <||>],
            combFile["ecg", #[[1]], #[[2]], r["sampler"], t] & /@ If[todo === {}, cells, todo],
            truthPath /@ cells,
            StringDrop[combName["log", "ecg", r["sampler"], t], -4]]]],
      {t, pickTargets[r["targets"]]}]]],
  planOf["ecgravRuns"]];

(* Settings the derived jobs read through the profile; run.wl only needs
   them to know which inputs to require. Defaults mirror the scripts.
   The summary files are global (all cells, all targets). With a cells or
   targets restriction, the jobs that write one are skipped: a partial run
   would overwrite the full summary, and later full runs would then skip it.
   The counts check writes nothing and always runs. *)
samplerSource = <|"mh" -> "mh", "exact" -> "ecgexact", "mcmc" -> "ecgmcmc",
  "legacyfacet" -> "ecglegacyfacet"|>;
(* Guarantee 6: a summary should not silently mix ECGrav commits within one
   kind of input (e.g. MH chains made before and after an ECGrav update).
   Each job lists its sampled inputs by family; printJob warns when a family
   holds more than one commit. Different families may differ by design (the
   efficiency summary compares samplers), and truth is left out: it is exact
   and its aut/autF were re-verified on the latest ECGrav. *)
commitLabel[f_] := With[{m = combManifest[f]}, Which[
  MissingQ[m], "no manifest",
  AssociationQ[m["backfilled"]], "backfilled " <> ToString[m["ecgravVersion"]],
  StringQ[m["ecgravCommit"]], StringTake[m["ecgravCommit"], UpTo[7]] <>
    If[StringEndsQ[m["ecgravCommit"], "-dirty"], "-dirty", ""],
  True, None]];                (* outputs made without ECGrav *)
mixedCommits[groups_Association] := Select[
  Counts[DeleteCases[commitLabel /@ Select[#, FileExistsQ], None]] & /@ groups, Length[#] > 1 &];
withInputs[j_, groups_] := Append[j, "commitGroups" -> groups];
samplesOf[src_, cells_] := Flatten[Table[combFile["samples", c[[1]], c[[2]], src, t], {c, cells}, {t, targets3}]];

$validate = "pipeline/50_validate.wl";
valJob[name_] := <|"COMB_VAL_JOB" -> {name, "job split"}|>;
jobsFor["validate"] := Module[{valCells, cells3w, ps, sources, out = {}, restricted, summaryJob},
  restricted = $cliCells =!= All || $cliTargets =!= All;
  summaryJob[j_] := If[restricted,
    Append[j, "skipReason" -> "writes a summary for all cells and targets; run validate without cells/targets"],
    j];
  valCells = pickCells[combSetting["COMB_VAL_CELLS", {{2, 4}, {2, 5}, {2, 6}, {2, 7},
    {3, 4}, {3, 5}, {3, 6}, {4, 4}, {4, 5}}, "cells"]];
  cells3w = pickCells[combSetting["COMB_3W_CELLS", {{3, 5}, {4, 5}}, "cells"]];
  ps = combSetting["COMB_CMP_PS", {2, 3, 4}, "intList"];
  (* default sources; a sampler word picks exactly one (legacyfacet only then) *)
  sources = Select[If[$cliSampler === All, {"mh", "ecgexact", "ecgmcmc"},
      If[KeyExistsQ[samplerSource, $cliSampler], {samplerSource[$cliSampler]}, {}]],
    AnyTrue[Flatten[Table[combFile["samples", c[[1]], c[[2]], #, t], {c, valCells}, {t, targets3}]],
      FileExistsQ] &];
  Which[
    $cliSampler =!= All && !KeyExistsQ[samplerSource, $cliSampler],
      Print["  note: sampler ", $cliSampler, " is not a validation source (mh, exact, mcmc, legacyfacet)"],
    $cliSampler =!= All && sources === {},
      Print["  note: no ", samplerSource[$cliSampler], " sample files for these cells; nothing to validate"]];
  AppendTo[out, job["counts vs truth", $validate,
    resolveKnobs[<||>, Join[valJob["counts"],
      If[$cliCells === All, <||>, <|"COMB_VAL_CELLS" -> {valCells, "cli"}|>]]], {},
    truthPath /@ valCells, "validate_counts"]];
  Do[AppendTo[out, summaryJob @ withInputs[job["validate " <> s, $validate,
      resolveKnobs[<||>, Join[valJob["samples"], <|"COMB_VAL_SOURCE" -> {s, "job split"}|>]],
      {combFile["validationSummary", s]}, truthPath /@ valCells, "validate_" <> s],
      <|s -> samplesOf[s, valCells]|>]],
    {s, sources}];
  If[$cliSampler === All,
    AppendTo[out, summaryJob @ job["sampler efficiency", $validate,
      resolveKnobs[<||>, valJob["efficiency"]],
      {combFile["summary", "sampler_efficiency"]}, truthPath /@ valCells, "compare_efficiency"] //
      withInputs[#, AssociationMap[samplesOf[#, valCells] &, {"mh", "ecgexact", "ecgmcmc"}]] &];
    If[cells3w =!= {},
      AppendTo[out, summaryJob @ job["3-way IS/MH/truth " <> envString[cells3w], $validate,
        resolveKnobs[<||>, valJob["3way"]],
        {combFile["summary", "is_mh_truth_3way"]},
        Flatten[Table[{truthPath[c], combFile["mh", c[[1]], c[[2]], t], combFile["isHist", c[[1]], c[[2]], t]},
          {c, cells3w}, {t, targets3}]], "compare_3way"] //
        withInputs[#, <|"mh" -> samplesOf["mh", cells3w],
          "isHist" -> Flatten[Table[combFile["isHist", c[[1]], c[[2]], t], {c, cells3w}, {t, targets3}]]|>] &]];
    AppendTo[out, summaryJob @ job["q=10 IS vs MH", $validate, resolveKnobs[<||>, valJob["q10_is_vs_mh"]],
      {combFile["summary", "q10_is_vs_mh"]},
      Flatten[Table[{combFile["isHist", p, 10, t], combFile["mh", p, 10, t]}, {p, ps}, {t, targets3}]],
      "compare_is_mh_q10"] // withInputs[#, <|
        "isHist" -> Flatten[Table[combFile["isHist", p, 10, t], {p, ps}, {t, targets3}]],
        "mh" -> Flatten[Table[combFile["mh", p, 10, t], {p, ps}, {t, targets3}]]|>] &];
    AppendTo[out, summaryJob @ job["q=10 warm vs prod", $validate, resolveKnobs[<||>, valJob["q10_warm_vs_prod"]],
      {combFile["summary", "q10_warm_vs_prod"]},
      Flatten[Table[{combFile["mh", p, 10, t], combFile["mh", p, 10, t, combMHWarmTag[67890, If[p == 3, 14, 18]]]},
        {p, {3, 4}}, {t, {"unlabeled", "facet"}}]], "compare_q10_warm_vs_prod"] //
      withInputs[#, <|"mh" -> Flatten[Table[{combFile["mh", p, 10, t],
        combFile["mh", p, 10, t, combMHWarmTag[67890, If[p == 3, 14, 18]]]},
        {p, {3, 4}}, {t, {"unlabeled", "facet"}}]]|>] &]];
  (* the summaries above as results/*.csv; "final": after the other jobs *)
  AppendTo[out, Append[job["results tables", $validate, resolveKnobs[<||>, valJob["results"]],
    {}, {}, "validate_results"], "final" -> True]];
  out];

fig[sub_, name_] := FileNameJoin[{$CombFiguresDir, sub, name}];
$figures = "pipeline/60_figures.wl";
figJob[name_] := resolveKnobs[<||>, <|"COMB_FIG_JOB" -> {name, "job split"}|>];
jobsFor["figures"] := If[$cliCells =!= All, {}, {
  job["Figure 2 (q=3)", $figures, figJob["fig2"],
    {combFile["fig2", 3, 3, 10000], fig["fig2", "p3q3_n10000_fig2_combined.pdf"]}, {}, "render_fig2"],
  job["truth overlay panels", $figures, figJob["truth_overlay"],
    {fig["combined", "combined_truth_overlay.pdf"]}, {truthPath[{3, 5}]}, "render_truth_overlay"],
  job["3-way grid", $figures, figJob["3way"],
    {fig["is_vs_mh", "q5_is_mh_truth_3way.pdf"]},
    (* the 3way job draws (3,5) and (4,5), whatever COMB_3W_CELLS says *)
    Flatten[Table[{truthPath[c], combFile["mh", c[[1]], c[[2]], t], combFile["isHist", c[[1]], c[[2]], t]},
      {c, {{3, 5}, {4, 5}}}, {t, targets3}]], "render_3way"],
  job["q=10 IS vs MH grid", $figures, figJob["q10_is_vs_mh"],
    {fig["is_vs_mh", "q10_is_vs_mh_grid.pdf"]},
    Flatten[Table[{combFile["isHist", p, 10, t], combFile["mh", p, 10, t]}, {p, {2, 3, 4}}, {t, targets3}]],
    "render_q10_is_vs_mh"],
  job["q=10 warm vs prod", $figures, figJob["q10_warm_vs_prod"],
    {fig["is_vs_mh", "q10_warm_vs_prod.pdf"]},
    Flatten[Table[{combFile["isHist", p, 10, t], combFile["mh", p, 10, t],
      combFile["mh", p, 10, t, combMHWarmTag[67890, If[p == 3, 14, 18]]]}, {p, {3, 4}}, {t, {"unlabeled", "facet"}}]],
    "render_q10_warm_vs_prod"],
  job["sampler MH progress", $figures, figJob["sampler_progress"],
    {fig["sampler_diagnostics", "sampler_mh_progress.pdf"]},
    {combFile["isStats", combISStem[4, 10, 500000]]}, "render_sampler_progress"],
  job["sampler MH uniformity", $figures, figJob["uniformity"],
    {fig["sampler_diagnostics", "sampler_mh_uniformity.pdf"]}, {}, "render_uniformity_check"],
  job["sampler ECGrav compare", $figures, figJob["ecgrav_compare"],
    {fig["sampler_diagnostics", "sampler_ecgrav_compare.pdf"]}, {}, "render_ecgrav_compare"],
  (* reads the pre-binned statistic histograms, not the merged stats *)
  job["q=10 manuscript figures", $figures, figJob["q10_stats"],
    {fig["combined", "combined_all_figures_merged.pdf"]},
    combFile["isStatHists", #, 10] & /@ {2, 3, 4}, "render_all_figures"]}];

(* ----- ECGrav commit and the stale report ----- *)
(* a relative COMB_ECGRAV_DIR is read from the checkout, as the jobs read it
   (they run with ProcessDirectory -> $code) *)
ecgravDir[] := With[{e = Environment["COMB_ECGRAV_DIR"]},
  Which[
    !StringQ[e] || e === "", FileNameJoin[{$CombRoot, "ECGrav-upstream"}],
    StringMatchQ[e, RegularExpression["^([A-Za-z]:|/|\\\\).*"]], ExpandFileName[e],
    True, ExpandFileName[FileNameJoin[{$code, e}]]]];
(* The same string ecgrav.wl records ($CombECGravCommit): "installed",
   the HEAD sha plus "-dirty" with local edits, or "unknown". It is what the
   regression record and the manifests hold, so the comparisons line up. *)
ecgravCommit[] := Module[{dir, top, sc, r, sha, dirty},
  If[Environment["COMB_ECGRAV_DIR"] === "installed", Return["installed"]];
  dir = ecgravDir[];
  (* git only when dir is itself a repo root, else SOURCE_COMMIT.txt *)
  top = Quiet @ RunProcess[{"git", "-C", dir, "rev-parse", "--show-toplevel"}, "StandardOutput"];
  If[!StringQ[top] || ExpandFileName[StringTrim[top]] =!= ExpandFileName[dir],
    sc = FileNameJoin[{dir, "SOURCE_COMMIT.txt"}];
    Return[If[FileExistsQ[sc],
      First[StringCases[Import[sc, "Text"], RegularExpression["[0-9a-f]{40}"]], "unknown"],
      "unknown"]]];
  r = Quiet @ RunProcess[{"git", "-C", dir, "rev-parse", "HEAD"}];
  If[!AssociationQ[r] || r["ExitCode"] =!= 0, Return["unknown"]];
  sha = StringTrim[r["StandardOutput"]];
  dirty = Quiet @ RunProcess[{"git", "-C", dir, "status", "--porcelain", "--untracked-files=no"},
    "StandardOutput"];
  If[StringQ[dirty] && StringTrim[dirty] =!= "", sha <> "-dirty", sha]];
regressionPassed[commit_] := With[{r = Quiet @ Get[FileNameJoin[{$CombResultsDir,
    "ecgrav_regression_passed.wl"}]]}, AssociationQ[r] && r["commit"] === commit];

staleReport[] := Module[{commit = ecgravCommit[], files, rows, cls, counts, flagged},
  files = Select[FileNames["*", $CombDataDir, Infinity],
    !DirectoryQ[#] && !StringEndsQ[#, ".manifest.wl" | ".tmp"] &&
      (* folders starting with "_" hold copies (_from_worktrees, _superseded), not outputs *)
      !StringStartsQ[StringReplace[StringDrop[#, StringLength[$CombDataDir] + 1], "\\" -> "/"], "_"] &];
  rows = Map[Function[f, Module[{m = combManifest[f], rel},
      rel = StringReplace[StringDrop[f, StringLength[$CombDataDir] + 1], "\\" -> "/"];
      cls = Which[
        MissingQ[m], "no manifest",
        AssociationQ[m["backfilled"]], "backfilled (ECGrav " <> ToString[m["ecgravVersion"]] <> ")",
        !StringQ[m["ecgravCommit"]], "current (no ECGrav)",
        m["ecgravCommit"] === commit, "current",
        True, "stale: ECGrav " <> StringTake[m["ecgravCommit"], UpTo[7]]];
      <|"file" -> rel, "class" -> cls,
        "status" -> If[AssociationQ[m] && AssociationQ[m["backfilled"]],
          m["provenance"]["status"], "ok"]|>]], files];
  counts = Counts[rows[[All, "class"]]];
  Print["== store report: ", $CombDataDir, " (ECGrav now ", StringTake[commit, UpTo[7]], ")"];
  KeyValueMap[Print["  ", pad[#1, 62], #2] &, ReverseSort[counts]];
  flagged = Select[rows, #["status"] =!= "ok" || StringStartsQ[#["class"], "stale" | "no manifest"] &];
  If[flagged =!= {},
    Print["  flagged (not rerun automatically; rerun a stage with force to replace):"];
    Scan[Print["    ", pad[#["file"], 46], pad[#["status"], 16], #["class"]] &,
      SortBy[flagged, {#["status"], #["file"]} &]]];
  rows];

jobsFor["check"] := Module[{out = {}, commit},
  If[!(StringQ[Environment["COMB_ECGRAV_DIR"]] && Environment["COMB_ECGRAV_DIR"] =!= ""),
    AppendTo[out, job["update ECGrav clone", "tools/dev/update_ecgrav.wl", <||>, {}, {},
      "check_update_ecgrav"]]];
  AppendTo[out, <|job["ECGrav regression",
      "tests/ecgrav_regression.wl", resolveKnobs[<||>, <||>], {},
      (* it compares against the truth grid; on a fresh store that comes later *)
      truthPath /@ combSetting["COMB_REG_CELLS", {{2, 4}, {2, 5}, {2, 6}, {2, 7}, {3, 4},
        {3, 5}, {3, 6}, {4, 4}, {4, 5}}, "cells"], "check_ecgrav_regression"],
    "when" -> Function[!regressionPassed[ecgravCommit[]]]|>];
  (* the enumerator smoke tests (old src/test_streaming*.wl) are in the
     package tests: CombResearch/Tests/Enumeration.wlt (Phase 5) *)
  out = Join[out, MapThread[job[#1, #2, <||>, {}, {}, #3] &, {
    {"smoke: package tests", "smoke: lib_names", "smoke: lib_config", "smoke: manifests"},
    {"CombResearch/Tests/run_tests.wl", "tests/lib_names_test.wl", "tests/lib_config_test.wl",
      "tests/manifest_test.wl"},
    {"check_package_tests", "check_lib_names", "check_lib_config", "check_manifest"}}]];
  out];

(* ----- running jobs ----- *)
printJob[j_, {action_, reason_}] := (
  Print["  ", pad[action, 5], pad[j["label"], 44], reason];
  If[KeyExistsQ[j, "commitGroups"],
    KeyValueMap[Print["        WARNING inputs mix ECGrav commits: ", #1, ": ",
      StringRiffle[KeyValueMap[Function[{c, n}, c <> " (" <> ToString[n] <> ")"], #2], ", "]] &,
      mixedCommits[j["commitGroups"]]]];
  If[$dryrun,
    Print["        ", j["script"], "   log ", FileNameTake[j["log"]]];
    KeyValueMap[Print["        ", pad[#1, 22], "= ", pad[#2[[1]], 24],
      " (", #2[[2]], ")"] &, j["knobs"]]]);

appendTo[file_, s_String] := If[s =!= "", With[{st = OpenAppend[file]}, WriteString[st, s]; Close[st]]];
drain[proc_, j_] := (
  appendTo[j["log"], Quiet @ Replace[ReadString[ProcessConnection[proc, "StandardOutput"], EndOfBuffer],
    Except[_String] -> ""]];
  appendTo[j["err"], Quiet @ Replace[ReadString[ProcessConnection[proc, "StandardError"], EndOfBuffer],
    Except[_String] -> ""]]);

(* Returns $Failed, starting nothing, when the job's lock already exists:
   CreateFile fails on an existing file, so two run.wl processes cannot both
   take the same lock. *)
startJob[j_] := Module[{env, proc, expect},
  If[!DirectoryQ[$CombLogsDir], CreateDirectory[$CombLogsDir]];
  If[Quiet[CreateFile[lockFile[j], OverwriteTarget -> False]] === $Failed, Return[$Failed]];
  Put[<|"label" -> j["label"], "runWlPid" -> $ProcessID, "host" -> $MachineName, "started" -> DateString["ISODateTime"]|>,
    lockFile[j]];
  AppendTo[$heldLocks, lockFile[j]];
  (* with the lock held, check once more: another run.wl may have finished
     the job between the check in runJobs and taking the lock *)
  If[!$force && ((j["outputs"] =!= {} && AllTrue[j["outputs"], FileExistsQ]) ||
      (KeyExistsQ[j, "doneWhen"] && AllTrue[j["doneWhen"], FileExistsQ])),
    releaseLock[j]; Return["outputs written by another run"]];
  (* decided now, before the job writes anything *)
  expect = expectWritten[j];
  Scan[If[FileExistsQ[#], DeleteFile[#]] &, {j["log"], j["err"]}];
  CreateFile /@ {j["log"], j["err"]};
  env = Join[dropNotInherited[Association[GetEnvironment[]]],
    <|"COMB_PROFILE" -> $profileName|>, #[[1]] & /@ j["knobs"]];
  (* at least 1 s between starts: wolframscript can crash at start-up
     (exit 0xC0000005, empty log) when several start in the same instant
     (Phase 7: 1 in 30 simultaneous starts; 0 in 45 with a 1 s gap) *)
  Pause[Max[0, 1 - (AbsoluteTime[] - $lastStart)]];
  $lastStart = AbsoluteTime[];
  proc = StartProcess[{"wolframscript", "-file", FileNameJoin[{$code, j["script"]}]},
    ProcessEnvironment -> env, ProcessDirectory -> $code];
  AppendTo[$children, proc];
  Print["  [", DateString[{"Hour", ":", "Minute", ":", "Second"}], "] start ", j["label"],
    "  -> logs/", FileNameTake[j["log"]]];
  <|"job" -> j, "proc" -> proc, "t0" -> AbsoluteTime[], "expect" -> expect|>];

(* Remove the lock only if this run.wl took it. *)
releaseLockFile[f_] := With[{l = Quiet @ Get[f]},
  If[AssociationQ[l] && l["runWlPid"] === $ProcessID, DeleteFile[f]];
  $heldLocks = DeleteCases[$heldLocks, f]];
releaseLock[j_] := releaseLockFile[lockFile[j]];
$heldLocks = {}; $children = {}; $lastStart = 0;

finishJob[r_, count_String : ""] := Module[{j = r["job"], code, bad, logText, written},
  (* the process has exited: read both streams to the end *)
  appendTo[j["log"], Quiet @ Replace[ReadString[ProcessConnection[r["proc"], "StandardOutput"]],
    Except[_String] -> ""]];
  appendTo[j["err"], Quiet @ Replace[ReadString[ProcessConnection[r["proc"], "StandardError"]],
    Except[_String] -> ""]];
  releaseLock[j];
  written = r["expect"];
  code = ProcessInformation[r["proc"], "ExitCode"];
  logText = Quiet @ ReadString[j["log"]];
  bad = Which[
    code =!= 0, "exit code " <> ToString[code],
    StringQ[logText] && StringContainsQ[logText, "$Aborted"], "aborted (see log)",
    AnyTrue[written, mtime[#] < r["t0"] - 1 &], "outputs not written: " <>
      StringRiffle[FileNameTake /@ Select[written, mtime[#] < r["t0"] - 1 &], ", "],
    True, None];
  Print["  [", DateString[{"Hour", ":", "Minute", ":", "Second"}], "] ",
    If[bad === None, "done  ", "FAILED"], " ", j["label"], "  (",
    Round[AbsoluteTime[] - r["t0"]], " s)", count, If[bad === None, "", "  " <> bad]];
  (* a failed job: show the end of its log, so the reason is visible here *)
  If[bad =!= None && StringQ[logText],
    Scan[Print["      | ", #] &,
      Take[#, -Min[4, Length[#]]] &[Select[StringSplit[StringDelete[logText, "\r"], "\n"],
        StringTrim[#] =!= "" &]]]];
  bad === None];

(* The last non-empty line of a log, read from its last 4 kB only (MH and IS
   logs grow large), cut to 100 characters. "" when there is none yet. *)
lastLogLine[file_] := Module[{st, size, txt, lines},
  If[!FileExistsQ[file], Return[""]];
  size = FileByteCount[file];
  st = Quiet @ OpenRead[file, BinaryFormat -> True];
  If[Head[st] =!= InputStream, Return[""]];
  SetStreamPosition[st, Max[0, size - 4096]];
  txt = Quiet @ ReadString[st]; Close[st];
  If[!StringQ[txt], Return[""]];
  lines = Select[StringSplit[StringDelete[txt, "\r"], "\n"], StringTrim[#] =!= "" &];
  If[lines === {}, "", StringTake[StringTrim[Last[lines]], UpTo[100]]]];

(* Progress while jobs run: every $heartbeat seconds, one line per running
   job with its time so far and the last line of its log. *)
$heartbeat = With[{e = Environment["COMB_TEST_HEARTBEAT"]},
  If[StringQ[e] && StringMatchQ[e, DigitCharacter ..], ToExpression[e], 60]];
heartbeatLine[r_] := Module[{t = Round[AbsoluteTime[] - r["t0"]], last},
  last = lastLogLine[r["job"]["log"]];
  Print["  [", DateString[{"Hour", ":", "Minute", ":", "Second"}], "] still running ",
    r["job"]["label"], "  (", If[t < 120, ToString[t] <> " s", ToString[Round[t / 60]] <> " min"],
    ")", If[last === "", "", "  | " <> last]]];

(* {before, total}: jobs of the stage finished before this call and in all,
   for the k/n count when a stage runs its jobs one call at a time (check). *)
runJobs[jobs_List, Optional[{before_Integer, total_Integer}, {0, -1}]] :=Module[{queue = jobs,
    running = {}, ok = True, done, finished = before, lastBeat = AbsoluteTime[],
    outOf = If[total < 0, Length[jobs], total]},
  While[queue =!= {} || running =!= {},
    While[ok && queue =!= {} && Length[running] < $maxJobs,
      Module[{j = First[queue], d, r},
        queue = Rest[queue];
        (* decided again at start: another run.wl may have taken the job or
           written its outputs since this stage was planned *)
        d = decide[j];
        r = If[d[[1]] === "skip", d, startJob[j]];
        Which[
          r === $Failed, finished++;
            Print["  skip  ", j["label"], ": locked by another run.wl (checked at start)"],
          StringQ[r], finished++; Print["  skip  ", j["label"], ": ", r, " (checked at start)"],
          ListQ[r], finished++; Print["  skip  ", j["label"], ": ", r[[2]], " (checked at start)"],
          True, AppendTo[running, r]]]];
    Pause[1];
    Scan[drain[#["proc"], #["job"]] &, running];
    done = Select[running, ProcessStatus[#["proc"]] =!= "Running" &];
    running = Complement[running, done];
    Scan[(finished++;
      If[!finishJob[#, If[outOf > 1, "  " <> ToString[finished] <> "/" <> ToString[outOf], ""]],
        ok = False]) &, done];
    If[running =!= {} && AbsoluteTime[] - lastBeat >= $heartbeat,
      lastBeat = AbsoluteTime[]; Scan[heartbeatLine, running]];
    If[!ok && queue =!= {}, Print["  stopping: a job failed; ", Length[queue], " not started"];
      queue = {}]];
  ok];

(* Labels of the jobs decided "skip" only because inputs are missing. *)
waitingOnInputs[decided_] := #[[1]]["label"] & /@ Select[decided,
  #[[2, 1]] === "skip" && StringStartsQ[#[[2, 2]], "inputs missing"] &];

(* Later passes of a stage: jobs whose inputs are other jobs' outputs in the
   same stage (q=10 batches -> merge per p -> q=10 histograms). After a pass
   that ran cleanly, the stage is planned again and the jobs that waited on
   inputs are decided again; those now "run" are run. Planned again, not
   re-decided from the old plan, so plan-time fields ("written") see the new
   files. Stops when nothing new runs, a job fails, or after $maxPasses. *)
$maxPasses = 4;
laterPasses[stage_, decided0_] := Module[{waiting = waitingOnInputs[decided0], ok = True,
    pass = 1, fresh, now},
  While[ok && waiting =!= {} && pass < $maxPasses,
    pass++;
    fresh = {#, decide[#]} & /@ Select[jobsFor[stage], MemberQ[waiting, #["label"]] &];
    now = Select[fresh, #[[2, 1]] === "run" &];
    If[now === {}, Break[]];
    Print["  -- pass ", pass, ": inputs written by the pass before"];
    Scan[printJob @@ # &, now];
    ok = runJobs[now[[All, 1]]];
    waiting = waitingOnInputs[fresh]];
  ok];

runStage[stage_] := Module[{jobs, decided, todo, finals},
  Print[""]; Print["== ", stage, "  (profile ", $profileName, If[$force, ", force", ""], ")"];
  jobs = jobsFor[stage];
  If[jobs === {}, Print["  nothing planned for this stage and these cells"]; Return[True]];
  (* A job with a "when" (the regression) is decided again right before it
     starts: it must see the commit the ECGrav update has just pulled. *)
  decided = {#, With[{d = decide[#]},
    If[KeyExistsQ[#, "when"] && d[[1]] === "run",
      {"run", "if the ECGrav commit has not passed (decided after the update)"}, d]]} & /@ jobs;
  If[stage === "check" && ($cliCells =!= All || $cliTargets =!= All),
    Print["  note: check ignores cells and targets (the regression uses COMB_REG_CELLS)"]];
  Scan[printJob @@ # &, decided];
  todo = Select[decided, #[[2, 1]] === "run" &][[All, 1]];
  (* "final" jobs (validate's results tables) read what the others write *)
  finals = Select[todo, TrueQ[Lookup[#, "final", False]] &];
  todo = Select[todo, !TrueQ[Lookup[#, "final", False]] &];
  If[$dryrun || (todo === {} && finals === {}), True,
    If[stage === "check",
      (* one at a time, stopping at the first failure *)
      Catch[MapIndexed[Which[
          KeyExistsQ[#1, "when"] && !#1["when"][],
            Print["  skip  ", #1["label"], ": ECGrav ", StringTake[ecgravCommit[], UpTo[7]],
              " already passed"],
          !runJobs[{#1}, {#2[[1]] - 1, Length[todo]}], Throw[False]] &, todo]; True],
      (todo === {} || (runJobs[todo] && laterPasses[stage, decided])) &&
        (finals === {} || runJobs[finals])]]];

(* ----- main ----- *)
Print["run.wl ", $stage, "  profile ", $profileName, "  store ", $CombRoot,
  If[$dryrun, "  (dry run)", ""]];
If[$leftover =!= <||>,
  With[{ign = KeySelect[$leftover, MemberQ[$notInherited, #] &],
      rest = KeySelect[$leftover, !MemberQ[$notInherited, #] &]},
    If[rest =!= <||>,
      Print["WARNING: COMB_* variables in this shell reach every job and win over the profile: ",
        StringRiffle[KeyValueMap[#1 <> "=" <> #2 &, rest], ", "]]];
    If[ign =!= <||>,
      Print["WARNING: ignored (run.wl sets these per job; use the force/cells/targets words): ",
        StringRiffle[KeyValueMap[#1 <> "=" <> #2 &, ign], ", "]]]]];

$ok = CheckAbort[Switch[$stage,
  "status", staleReport[]; True,
  "all", Module[{r = True},
    Do[If[r, r = runStage[s]], {s, $stages}];
    If[r, staleReport[]]; r],
  "check", With[{r = runStage["check"]}, staleReport[]; r],
  _, runStage[$stage]],
  (* stop the jobs this run.wl started, then release their locks, so the
     next run neither finds stale locks nor races a still-running job *)
  Print["run.wl: aborted; stopping ", Count[$children, p_ /; ProcessStatus[p] === "Running"],
    " running job(s)"];
  Scan[If[ProcessStatus[#] === "Running", KillProcess[#]] &, $children];
  Scan[releaseLockFile, $heldLocks];
  False];

Print[""];
Print["run.wl: ", If[$dryrun, "dry run, nothing started", If[TrueQ[$ok], "ok", "FAILED"]]];
Exit[If[TrueQ[$ok], 0, 1]];
