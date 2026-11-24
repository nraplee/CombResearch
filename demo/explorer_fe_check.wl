(* explorer_fe_check.wl
   Opens CombResearchExplorer.nb in a hidden front end, evaluates it with the
   front end's own kernel (as a user does), runs a job of each panel, checks
   that the kernel answers the progress box while a job runs and that the Stop
   button's command stops it, and saves pictures of the notebook. A hidden
   window does not refresh by itself and nothing is clicked: that is left to
   a person (README.md).

     wolframscript -file demo/explorer_fe_check.wl [picture folder]

   Needs a desktop Mathematica (not just the Wolfram Engine). About 2 min. *)

failures = {};
check[name_, cond_] := (
  Print[If[TrueQ[cond], "  ok    ", "  FAIL  "], name];
  If[!TrueQ[cond], AppendTo[failures, name]]);

dir = DirectoryName[$InputFileName];
pics = If[Length[$ScriptCommandLine] > 1, $ScriptCommandLine[[2]],
  CreateDirectory[]];
If[!DirectoryQ[pics], CreateDirectory[pics]];
picture[nb_, name_] := (Pause[2];
  Export[FileNameJoin[{pics, name <> ".png"}], Rasterize[nb, ImageResolution -> 72]]);

waitFor[cond_, seconds_] := Module[{t0 = AbsoluteTime[]},
  While[!TrueQ[cond[]] && AbsoluteTime[] - t0 < seconds, Pause[0.5]]; TrueQ[cond[]]];

(* front end <-> notebook kernel: a job cell in a helper notebook writes its
   result into a front end variable *)
feValue[key_] := CurrentValue[$FrontEndSession, {TaggingRules, "ExplorerCheck", key}];
send[helper_, code_String] := (
  SelectionMove[helper, After, Notebook];
  NotebookWrite[helper, Cell[code, "Input"], All];
  SelectionEvaluate[helper]);
job[helper_, key_, code_] := (
  CurrentValue[$FrontEndSession, {TaggingRules, "ExplorerCheck", key}] = "waiting";
  send[helper, "CurrentValue[$FrontEndSession, {TaggingRules, \"ExplorerCheck\", \"" <>
    key <> "\"}] = ToString[(" <> code <> "), InputForm];"]);
result[helper_, key_, code_, seconds_] := (job[helper, key, code];
  waitFor[feValue[key] =!= "waiting" &, seconds]; feValue[key]);

UsingFrontEnd[
  nb = NotebookOpen[FileNameJoin[{dir, "CombResearchExplorer.nb"}], Visible -> False];
  SetOptions[nb, Evaluator -> "Local"];
  helper = CreateDocument[{}, Visible -> False, Evaluator -> "Local"];

  FrontEndTokenExecute[nb, "EvaluateNotebook"];
  check["notebook evaluates: 4 panels",
    waitFor[Length[Cells[nb, CellStyle -> "Output"]] >= 4 &, 120]];
  check["panels say so in a fresh kernel", Module[{texts},
    texts = Cases[NotebookRead /@ Cells[nb, CellStyle -> "Output"],
      s_String /; StringContainsQ[s, "The kernel has restarted"], Infinity];
    Length[texts] >= 4]];
  check["no messages", Cells[nb, CellStyle -> {"Message", "MSG"}] === {}];
  outputs = NotebookRead /@ Cells[nb, CellStyle -> "Output"];
  check["every panel is interactive boxes", AllTrue[outputs,
    !FreeQ[#, ButtonBox] && !FreeQ[#, DynamicBox] &]];
  picture[nb, "1_started"];

  check["loaded in the notebook's kernel",
    result[helper, "ready", "CombExplorer`$ExplorerReady", 30] === "True"];

  job[helper, "enum34", "CombExplorer`Private`runEnumeration[3, 4, Automatic]; " <>
    "{Length[CombExplorer`Private`$result[\"reps\"]], " <>
    "CombExplorer`Private`$result[\"kernels\"] > 0}"];
  waitFor[feValue["enum34"] =!= "waiting" &, 120];
  Print["  ", feValue["enum34"]];
  check["panel 1: (3,4) in parallel gives 66 classes", feValue["enum34"] === "{66, True}"];
  picture[nb, "2_enumerated"];

  job[helper, "stop", "CombExplorer`Private`$jobPanel = \"enumerate\"; CombExplorer`Private`runEnumeration[3, 5, Automatic]; " <>
    "CombExplorer`Private`$view1 === CombExplorer`Private`note[\"Stopped.\"]"];
  (* only the progress boxes change while the job runs *)
  Pause[6];
  frames = Table[Pause[3]; ImageData[Rasterize[nb, ImageResolution -> 72], "Byte"], {3}];
  picture[nb, "3_running"];
  check["job is running", feValue["stop"] === "waiting"];
  check["the progress box is answered while a job runs", DuplicateFreeQ[frames]];
  t0 = AbsoluteTime[];
  FrontEndTokenExecute[helper, "EvaluatorAbort"];
  check["Stop command stops the job", waitFor[feValue["stop"] =!= "waiting" &, 20] &&
    feValue["stop"] === "True"];
  Print["  stopped after ", Round[AbsoluteTime[] - t0, 0.1], " s"];

  check["parallel off: (2,4) on one kernel", result[helper, "serial",
    "CombExplorer`$ExplorerParallel = False; CombExplorer`Private`runEnumeration[2, 4, Automatic]; " <>
      "CombExplorer`$ExplorerParallel = True; " <>
      "{Length[CombExplorer`Private`$result[\"reps\"]], CombExplorer`Private`$result[\"kernels\"]}",
    60] === "{11, 0}"];
  check["panel 2: class 5", result[helper, "stat",
    "CombExplorer`Private`selectClass[5]; FreeQ[CombExplorer`Private`$view2, Graphics]", 60] === "False"];
  If[result[helper, "stored", "CombExplorer`ExplorerTruthFile[3, 5] =!= None", 30] === "True",
    check["panel 3: stored cell (3,5)", result[helper, "dist",
      "CombExplorer`Private`showCell[{3, 5}]; CombExplorer`Private`$truth[\"numIsoClasses\"]", 60] === "445"],
    Print["  skip  panel 3: stored cell (3,5): no truth file"]];
  picture[nb, "4_all_panels"];
  check["panel 3: live cell (3,3)", result[helper, "live",
    "CombExplorer`Private`showCell[{3, 3}]; CombExplorer`Private`$truth[\"source\"]", 90] === "\"live\""];
  picture[nb, "5_live_cell"];
  check["still no messages", Cells[nb, CellStyle -> {"Message", "MSG"}] === {} &&
    Cells[helper, CellStyle -> {"Message", "MSG"}] === {}];
  result[helper, "end", "CloseKernels[]; 1", 30];
  NotebookClose[helper, Interactive -> False];
  NotebookClose[nb, Interactive -> False]];

Print["pictures in ", pics];
Print[If[failures === {}, "ALL PASS",
  ToString[Length[failures]] <> " FAILED: " <> ToString[failures]]];
Exit[If[failures === {}, 0, 1]];
