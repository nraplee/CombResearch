(* run.wl
   One entry point over the repo's .wl drivers (Phase 3 of
   docs/architecture/implementation-plan.md).

     wolframscript -file run.wl <stage> [option ...]

   Stages, in the order "all" runs them:
     check     update the shared ECGrav clone, run tests\ecgrav_regression.wl
               if that commit has not passed, run the smoke tests, report
               stale outputs
     truth     enumerate_truth.wl, one process per truth run of the profile
     is        q=10 IS batches (run_p{p}.wl, one process per p and batch),
               IS at the truth cells (run_is_at_truth_cells.wl), and the
               q=10 numV histograms (precompute_is_histograms_q10.wl)
     mh        run_mh_chains.wl, one process per cell and target
     ecgrav    run_ecgrav_samplers.wl, one process per sampler and target
     validate  counts, MH/ECGrav validation, efficiency and comparison
               summaries; warns when one kind of input (e.g. the MH chains)
               mixes ECGrav commits (guarantee 6, from the manifests)
     figures   the render_*.wl scripts
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
   with that reason.

   Settings (guarantee 3): each job's COMB_* knobs come from the command
   line, else the parent environment (a leftover env var wins over the
   profile, with a warning), else the profile's run plan; anything else is
   left to the driver, which resolves it through lib_config.wl with
   COMB_PROFILE set.

   Logs go to $CombLogsDir under the launchers' names
   (mh_p{p}q{q}_{target}.log, ecg{sampler}_{target}.log,
   compute_p{p}[_{runTag}].log, plus .err), so monitor_mh.ps1 and
   monitor_ecgrav.ps1 work on run.wl runs.

   A job counts as done only if wolframscript exits 0, its log has no
   "$Aborted", and every declared output exists and was written after the
   job started (an Abort[] still exits 0). *)

$code = DirectoryName[$InputFileName];
$src = FileNameJoin[{$code, "src"}];
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
    Get[FileNameJoin[{$src, "lib_names.wl"}]];
    Get[FileNameJoin[{$src, "lib_config.wl"}]];
    Get[FileNameJoin[{$src, "lib_io.wl"}]]; True, False] =!= True,
  Print["run.wl: loading src/lib_*.wl aborted"]; Exit[1]];

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
$identityKnobs = {"COMB_TRUTH_CELLS", "COMB_TRUTH_PIPELINE", "COMB_N", "COMB_RUNTAG",
  "COMB_NN_FIXED", "COMB_IS_CELLS", "COMB_MH_CELLS", "COMB_MH_TARGETS", "COMB_MH_TAG",
  "COMB_ECG_SAMPLER", "COMB_ECG_CELLS", "COMB_ECG_TARGETS", "COMB_VAL_SOURCE",
  "COMB_VAL_CELLS", "COMB_VAL_TARGETS", "COMB_EFF_CELLS", "COMB_EFF_TARGETS",
  "COMB_3W_CELLS", "COMB_3W_TARGETS", "COMB_FIG2_N"};
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
   (another shell) does not start it again. A crash can leave one behind;
   delete it by hand then. *)
lockFile[j_] := j["log"] <> ".lock";

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
    FileExistsQ[lockFile[j]], {"skip", "locked: " <> FileNameTake[lockFile[j]] <>
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

pipeFile[{p_, q_}, pipeline_] := combFile["truth", p, q, pipeline];
jobsFor["truth"] := Flatten @ Map[Function[r, Module[{cells, pl = r["pipeline"], pending, todo, use, j},
    cells = pickCells[r["cells"]];
    (* A non-cheap pipeline writes _truth_<pipeline>.wxf; the canonical
       _truth.wxf is a manual rename (Phase 4 automates it). A cell whose
       pipeline file exists but canonical file does not is waiting for that
       rename, not for a rerun. *)
    pending = If[pl === "cheap" || $force, {},
      Select[cells, !FileExistsQ[truthPath[#]] && FileExistsQ[pipeFile[#, pl]] &]];
    todo = If[$force, cells, Select[cells, !FileExistsQ[truthPath[#]] && !MemberQ[pending, #] &]];
    use = If[todo === {}, cells, todo];
    If[cells === {}, {},
      j = job["truth " <> pl <> " " <> envString[cells], "src/enumerate_truth.wl",
        resolveKnobs[<|"COMB_TRUTH_PARALLEL" -> If[TrueQ[r["parallel"]], "true", "false"]|>,
          <|"COMB_TRUTH_CELLS" -> cliOr[use], "COMB_TRUTH_PIPELINE" -> {pl, "job split"}|>],
        truthPath /@ use, {}, "truth_" <> pl] ~Join~
        <|"written" -> (pipeFile[#, pl] & /@ use)|>;
      (* checked again at start: another run.wl may finish this pipeline run *)
      If[pl =!= "cheap", j["doneWhen"] = pipeFile[#, pl] & /@ use];
      If[todo === {} && pending =!= {},
        j["skipReason"] = "rename " <> StringRiffle[FileNameTake[pipeFile[#, pl]] <> " -> " <>
          FileNameTake[truthPath[#]] & /@ pending, ", "] <> " (" <> pl <> " output present)"];
      If[pending =!= {} && todo =!= {},
        Print["  note: ", pl, " output waiting for rename: ",
          StringRiffle[FileNameTake[pipeFile[#, pl]] & /@ pending, ", "]]];
      j]]],
  planOf["truthRuns"]];

jobsFor["is"] := Module[{batches = planOf["isBatches"], out = {}, cellsIS},
  KeyValueMap[Function[{p, bs},
    If[$cliCells === All || MemberQ[$cliCells, {p, 10}],
      Do[With[{runTag = b[[1]], n = b[[2]], chunk = b[[3]],
          stem = combISStem[p, 10, b[[2]], None, b[[1]]]},
        AppendTo[out, job["is q=10 p=" <> ToString[p] <> " " <> If[runTag === "", "batch1", runTag],
          "src/run_p" <> ToString[p] <> ".wl",
          resolveKnobs[<|"COMB_N" -> n, "COMB_RUNTAG" -> runTag, "COMB_CHUNK" -> chunk|>, <||>],
          (* skip on the stats file only: batches 1 and 2 were migrated from CSV
             and never had a complexes file *)
          {combFile["isStats", stem]}, {},
          StringDrop[combName["log", "compute", p, If[runTag === "", "", "_" <> runTag]], -4]] ~Join~
          <|"written" -> {combFile["isStats", stem], combFile["isComplexes", stem]},
            (* pure_simplicial_compute.wl skips a p whose final stats exist and
               has no force knob *)
            "noForce" -> "force cannot rerun a q=10 batch: the driver skips a finished batch; " <>
              "move " <> FileNameTake[combFile["isStats", stem]] <> " away first"|>]],
        {b, bs}]]], batches];
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
        j = job["is at truth cells " <> envString[cellsIS], "src/run_is_at_truth_cells.wl",
          resolveKnobs[<||>, <|"COMB_IS_CELLS" -> {If[todo === {}, cellsIS, todo],
            If[$cliCells === All, $CombSettings["COMB_IS_CELLS"]["source"], "cli"]}|>],
          hists[cellsIS], {}, "is_truth_cells"] ~Join~
          <|"written" -> hists[If[todo === {} || $force, cellsIS, todo]]|>;
        If[partial =!= {},
          With[{msg = "cells with only some hists (rerunning would overwrite the others; use force): " <>
              envString[partial]},
            If[todo === {}, j["skipReason"] = msg, Print["  note: ", msg]]]];
        AppendTo[out, j]]]];
  (* q=10 numV histograms from the merged stats; here, not in validate, so the
     q=10 comparisons there always see them finished. *)
  If[$cliCells === All,
    AppendTo[out, job["q=10 IS histograms", "src/precompute_is_histograms_q10.wl",
      resolveKnobs[<||>, <||>],
      Flatten[Table[combFile["isHist", p, 10, t], {p, {2, 3, 4}}, {t, targets3}]],
      combFile["isStats", combMergedStem[#, 10]] & /@ {2, 3, 4}, "precompute_is_q10"]]];
  out];

jobsFor["mh"] := Flatten @ Map[Function[g, Module[{tag = Lookup[g, "tag", ""]},
    Table[
      With[{p = c[[1]], q = c[[2]]},
        job["mh " <> combCell[p, q] <> " " <> t <> tag, "src/run_mh_chains.wl",
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
          job["ecg" <> r["sampler"] <> " " <> t, "src/run_ecgrav_samplers.wl",
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
  AppendTo[out, job["counts vs truth", "src/validate_counts_vs_truth.wl",
    resolveKnobs[<||>, If[$cliCells === All, <||>, <|"COMB_VAL_CELLS" -> {valCells, "cli"}|>]], {},
    truthPath /@ valCells, "validate_counts"]];
  Do[AppendTo[out, summaryJob @ withInputs[job["validate " <> s, "src/validate_mh_vs_truth.wl",
      resolveKnobs[<||>, <|"COMB_VAL_SOURCE" -> {s, "job split"}|>],
      {combFile["validationSummary", s]}, truthPath /@ valCells, "validate_" <> s],
      <|s -> samplesOf[s, valCells]|>]],
    {s, sources}];
  If[$cliSampler === All,
    AppendTo[out, summaryJob @ job["sampler efficiency", "src/compare_samplers_efficiency.wl",
      resolveKnobs[<||>, <||>],
      {combFile["summary", "sampler_efficiency"]}, truthPath /@ valCells, "compare_efficiency"] //
      withInputs[#, AssociationMap[samplesOf[#, valCells] &, {"mh", "ecgexact", "ecgmcmc"}]] &];
    If[cells3w =!= {},
      AppendTo[out, summaryJob @ job["3-way IS/MH/truth " <> envString[cells3w], "src/compare_3way.wl",
        resolveKnobs[<||>, <||>],
        {combFile["summary", "is_mh_truth_3way"]},
        Flatten[Table[{truthPath[c], combFile["mh", c[[1]], c[[2]], t], combFile["isHist", c[[1]], c[[2]], t]},
          {c, cells3w}, {t, targets3}]], "compare_3way"] //
        withInputs[#, <|"mh" -> samplesOf["mh", cells3w],
          "isHist" -> Flatten[Table[combFile["isHist", c[[1]], c[[2]], t], {c, cells3w}, {t, targets3}]]|>] &]];
    AppendTo[out, summaryJob @ job["q=10 IS vs MH", "src/compare_is_mh_q10.wl", resolveKnobs[<||>, <||>],
      {combFile["summary", "q10_is_vs_mh"]},
      Flatten[Table[{combFile["isHist", p, 10, t], combFile["mh", p, 10, t]}, {p, ps}, {t, targets3}]],
      "compare_is_mh_q10"] // withInputs[#, <|
        "isHist" -> Flatten[Table[combFile["isHist", p, 10, t], {p, ps}, {t, targets3}]],
        "mh" -> Flatten[Table[combFile["mh", p, 10, t], {p, ps}, {t, targets3}]]|>] &];
    AppendTo[out, summaryJob @ job["q=10 warm vs prod", "src/compare_q10_warm_vs_prod.wl", resolveKnobs[<||>, <||>],
      {combFile["summary", "q10_warm_vs_prod"]},
      Flatten[Table[{combFile["mh", p, 10, t], combFile["mh", p, 10, t, combMHWarmTag[67890, If[p == 3, 14, 18]]]},
        {p, {3, 4}}, {t, {"unlabeled", "facet"}}]], "compare_q10_warm_vs_prod"] //
      withInputs[#, <|"mh" -> Flatten[Table[{combFile["mh", p, 10, t],
        combFile["mh", p, 10, t, combMHWarmTag[67890, If[p == 3, 14, 18]]]},
        {p, {3, 4}}, {t, {"unlabeled", "facet"}}]]|>] &]];
  out];

fig[sub_, name_] := FileNameJoin[{$CombFiguresDir, sub, name}];
jobsFor["figures"] := If[$cliCells =!= All, {}, {
  job["Figure 2 (q=3)", "src/render_fig2.wl", resolveKnobs[<||>, <||>],
    {combFile["fig2", 3, 3, 10000], fig["fig2", "p3q3_n10000_fig2_combined.pdf"]}, {}, "render_fig2"],
  job["truth overlay panels", "src/render_truth_overlay.wl", resolveKnobs[<||>, <||>],
    {fig["combined", "combined_truth_overlay.pdf"]}, {truthPath[{3, 5}]}, "render_truth_overlay"],
  job["3-way grid", "src/render_3way.wl", resolveKnobs[<||>, <||>],
    {fig["is_vs_mh", "q5_is_mh_truth_3way.pdf"]},
    (* render_3way.wl draws (3,5) and (4,5), whatever COMB_3W_CELLS says *)
    Flatten[Table[{truthPath[c], combFile["mh", c[[1]], c[[2]], t], combFile["isHist", c[[1]], c[[2]], t]},
      {c, {{3, 5}, {4, 5}}}, {t, targets3}]], "render_3way"],
  job["q=10 IS vs MH grid", "src/render_q10_is_vs_mh.wl", resolveKnobs[<||>, <||>],
    {fig["is_vs_mh", "q10_is_vs_mh_grid.pdf"]},
    Flatten[Table[{combFile["isHist", p, 10, t], combFile["mh", p, 10, t]}, {p, {2, 3, 4}}, {t, targets3}]],
    "render_q10_is_vs_mh"],
  job["q=10 warm vs prod", "src/render_q10_warm_vs_prod.wl", resolveKnobs[<||>, <||>],
    {fig["is_vs_mh", "q10_warm_vs_prod.pdf"]},
    Flatten[Table[{combFile["isHist", p, 10, t], combFile["mh", p, 10, t],
      combFile["mh", p, 10, t, combMHWarmTag[67890, If[p == 3, 14, 18]]]}, {p, {3, 4}}, {t, {"unlabeled", "facet"}}]],
    "render_q10_warm_vs_prod"],
  job["sampler MH progress", "src/render_sampler_progress.wl", resolveKnobs[<||>, <||>],
    {fig["sampler_diagnostics", "sampler_mh_progress.pdf"]},
    {combFile["isSamplesCSV", combISStem[4, 10, 500000]]}, "render_sampler_progress"],
  job["sampler MH uniformity", "src/render_uniformity_check.wl", resolveKnobs[<||>, <||>],
    {fig["sampler_diagnostics", "sampler_mh_uniformity.pdf"]}, {}, "render_uniformity_check"],
  job["sampler ECGrav compare", "src/render_ecgrav_compare.wl", resolveKnobs[<||>, <||>],
    {fig["sampler_diagnostics", "sampler_ecgrav_compare.pdf"]}, {}, "render_ecgrav_compare"],
  job["q=10 manuscript figures", "src/render_all_figures.wl", resolveKnobs[<||>, <||>],
    {fig["combined", "combined_all_figures_merged.pdf"]},
    combFile["isStats", combMergedStem[#, 10]] & /@ {2, 3, 4}, "render_all_figures"]}];

(* ----- ECGrav commit and the stale report ----- *)
(* a relative COMB_ECGRAV_DIR is read from the checkout, as the jobs read it
   (they run with ProcessDirectory -> $code) *)
ecgravDir[] := With[{e = Environment["COMB_ECGRAV_DIR"]},
  Which[
    !StringQ[e] || e === "", FileNameJoin[{$CombRoot, "ECGrav-upstream"}],
    StringMatchQ[e, RegularExpression["^([A-Za-z]:|/|\\\\).*"]], ExpandFileName[e],
    True, ExpandFileName[FileNameJoin[{$code, e}]]]];
(* The same string load_ecgrav.wl records ($CombECGravCommit): "installed",
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
      !StringContainsQ[#, "_from_worktrees"] &];
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
  out = Join[out, MapThread[job[#1, #2, <||>, {}, {}, #3] &, {
    {"smoke: streaming", "smoke: streaming McKay", "smoke: lib_names", "smoke: lib_config", "smoke: manifests"},
    {"src/test_streaming.wl", "src/test_streaming_mckay.wl", "tests/lib_names_test.wl",
      "tests/lib_config_test.wl", "tests/manifest_test.wl"},
    {"check_test_streaming", "check_test_streaming_mckay", "check_lib_names", "check_lib_config",
      "check_manifest"}}]];
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
  Put[<|"label" -> j["label"], "runWlPid" -> $ProcessID, "started" -> DateString["ISODateTime"]|>,
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
  proc = StartProcess[{"wolframscript", "-file", FileNameJoin[{$code, j["script"]}]},
    ProcessEnvironment -> env, ProcessDirectory -> $code];
  AppendTo[$children, proc];
  Print["  [", DateString[{"Hour", ":", "Minute", ":", "Second"}], "] start ", j["label"],
    "  -> logs\\", FileNameTake[j["log"]]];
  <|"job" -> j, "proc" -> proc, "t0" -> AbsoluteTime[], "expect" -> expect|>];

(* Remove the lock only if this run.wl took it. *)
releaseLockFile[f_] := With[{l = Quiet @ Get[f]},
  If[AssociationQ[l] && l["runWlPid"] === $ProcessID, DeleteFile[f]];
  $heldLocks = DeleteCases[$heldLocks, f]];
releaseLock[j_] := releaseLockFile[lockFile[j]];
$heldLocks = {}; $children = {};

finishJob[r_] := Module[{j = r["job"], code, bad, logText, written},
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
    Round[AbsoluteTime[] - r["t0"]], " s)", If[bad === None, "", "  " <> bad]];
  bad === None];

runJobs[jobs_List] := Module[{queue = jobs, running = {}, ok = True, done},
  While[queue =!= {} || running =!= {},
    While[ok && queue =!= {} && Length[running] < $maxJobs,
      Module[{j = First[queue], d, r},
        queue = Rest[queue];
        (* decided again at start: another run.wl may have taken the job or
           written its outputs since this stage was planned *)
        d = decide[j];
        r = If[d[[1]] === "skip", d, startJob[j]];
        Which[
          r === $Failed, Print["  skip  ", j["label"], ": locked by another run.wl (checked at start)"],
          StringQ[r], Print["  skip  ", j["label"], ": ", r, " (checked at start)"],
          ListQ[r], Print["  skip  ", j["label"], ": ", r[[2]], " (checked at start)"],
          True, AppendTo[running, r]]]];
    Pause[1];
    Scan[drain[#["proc"], #["job"]] &, running];
    done = Select[running, ProcessStatus[#["proc"]] =!= "Running" &];
    running = Complement[running, done];
    Scan[If[!finishJob[#], ok = False] &, done];
    If[!ok && queue =!= {}, Print["  stopping: a job failed; ", Length[queue], " not started"];
      queue = {}]];
  ok];

runStage[stage_] := Module[{jobs, decided, todo},
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
  If[$dryrun || todo === {}, True,
    If[stage === "check",
      (* one at a time, stopping at the first failure *)
      Catch[Scan[Which[
          KeyExistsQ[#, "when"] && !#["when"][],
            Print["  skip  ", #["label"], ": ECGrav ", StringTake[ecgravCommit[], UpTo[7]],
              " already passed"],
          !runJobs[{#}], Throw[False]] &, todo]; True],
      runJobs[todo]]]];

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
