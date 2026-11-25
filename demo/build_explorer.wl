(* build_explorer.wl
   Writes demo/CombResearchExplorer.nb. The notebook is only the text and
   one line per panel; the code is explorer_core.wl and explorer_panels.wl,
   so this file and those two are what to review and edit.

     wolframscript -file demo/build_explorer.wl

   No front end, ECGrav or data needed. The output is the same on every run
   (no dates, no machine paths), so git shows a change only when there is
   one. *)

Module[{dir = DirectoryName[$InputFileName], text, code, cells, nb, out, body},
  text[s_, style_: "Text"] := Cell[s, style];
  code[s_] := Cell[s, "Input", InitializationCell -> True];

  cells = {
    text["CombResearch Explorer", "Title"],
    text["Pure simplicial complexes with q facets of size p: exact enumeration, \
statistics and distributions", "Subtitle"],
    text["To start: Evaluation \[FilledRightTriangle] Evaluate Notebook (or the button \
below). Needs Wolfram 15 or later and this repository; ECGrav is taken from \
COMB_ECGRAV_DIR if set, else ECGrav-upstream next to run.wl, else the installed paclet."],
    Cell[BoxData[ToBoxes[Button["Start: evaluate the notebook",
      FrontEndTokenExecute["EvaluateNotebook"], ImageSize -> Automatic]]], "Text"],
    text["The notebook only reads: it never writes into data/, figures/, logs/ or \
results/. Long jobs run on parallel kernels, show progress, and have a Stop button \
(Evaluation \[FilledRightTriangle] Abort Evaluation does the same, except while kernels \
are starting). The first job starts the kernels, which takes some seconds."],
    code["Get[FileNameJoin[{NotebookDirectory[], \"explorer_core.wl\"}]];\n\
Get[FileNameJoin[{NotebookDirectory[], \"explorer_panels.wl\"}]];"],
    code["ExplorerStatusPanel[]"],

    text["1. Enumerate", "Section"],
    text["EnumerateUnlabeledPureComplexes[p, q] lists one complex of every isomorphism \
class. Automatic is the McKay method for p \[GreaterEqual] 4 and Cheap below that. The table \
compares the number of classes with n vertices with ECGrav's NumUnlabeledPureComplexes \
and, where we have it, our stored truth. Start with (3, 4): 66 classes in a few seconds; \
(3, 5) takes minutes."],
    code["ExplorerEnumeratePanel[]"],

    text["2. Statistics", "Section"],
    text["PureComplexStatistics[complex, p] gives the 12 statistics named in \
$PureComplexStatisticNames. Take a complex from panel 1, draw one at random with ECGrav, \
or type one in. The first draw uniform over unlabeled complexes at a cell computes \
ECGrav's counts for it: about 20 s at (3, 10), minutes at (4, 9) and (4, 10). Later draws \
at the same cell are fast."],
    code["ExplorerStatisticsPanel[]"],

    text["3. Exact distributions", "Section"],
    text["PureComplexTruthMarginal[truth, target, statistic] gives the exact distribution \
of a statistic when the complex is uniform over unlabeled, facet-labeled or \
vertex-labeled complexes. A good start is (3, 5) with numV: the vertex-labeled \
distribution sits at much larger numbers of vertices than the other two. Cells marked \
stored are read from our truth files (data/ of the main checkout, else the copies in \
demo/data); the others are enumerated when you press Show."],
    code["ExplorerDistributionPanel[]"]};

  nb = Notebook[cells,
    WindowSize -> {980, 900}, WindowTitle -> "CombResearch Explorer",
    ShowCellLabel -> False, StyleDefinitions -> "Default.nb"];

  body = ToString[nb, InputForm, PageWidth -> 78, CharacterEncoding -> "ASCII"];
  out = FileNameJoin[{dir, "CombResearchExplorer.nb"}];
  Module[{s = OpenWrite[out, BinaryFormat -> True]},
    BinaryWrite[s, ToCharacterCode[
      "(* Content-type: application/vnd.wolfram.mathematica *)\n\n" <>
      "(* Written by demo/build_explorer.wl: edit that, not this file. *)\n\n" <>
      body <> "\n"]];
    Close[s]];
  Print["wrote ", out, "  (", FileByteCount[out], " bytes, ", Length[cells], " cells)"]];
