(* Diagnose ESS collapse: look at top weights and what samples produce them. *)
outputDir = DirectoryName[$InputFileName];

Do[
  Module[{path, raw, body, numV, aut, autF, wU, wF, n, topU, topF},
    path = FileNameJoin[{outputDir,
      "p" <> ToString[p] <> "q10_n500000_samples.csv"}];
    raw = Import[path, "CSV"];
    body = Rest[raw];
    numV = N[ToExpression /@ body[[All, 1]]];
    aut  = N[ToExpression /@ body[[All, 2]]];
    autF = N[ToExpression /@ body[[All, 3]]];
    wU = N[ToExpression /@ body[[All, 14]]];
    wF = N[ToExpression /@ body[[All, 15]]];
    n = Length[wU];

    Print["===== p = ", p, " ====="];
    Print["N samples: ", n];
    Print["numV range: ", {Min[numV], Max[numV]}, "  median: ", Median[numV]];

    Print["-- unlabeled weights --"];
    Print["  total w        : ", Total[wU]];
    Print["  max w          : ", Max[wU]];
    Print["  max / total    : ", Max[wU] / Total[wU]];
    Print["  ESS            : ", N[Total[wU]^2 / Total[wU^2]]];
    topU = Reverse[Ordering[wU]][[;; 5]];
    Print["  top 5 sample idx, numV, |Aut|, weight, weight/total:"];
    Do[Print["    ", i, "  numV=", numV[[i]], "  |Aut|=", aut[[i]],
       "  w=", wU[[i]], "  share=", N[wU[[i]] / Total[wU]]],
      {i, topU}];

    Print["-- facet weights --"];
    Print["  total w        : ", Total[wF]];
    Print["  max w          : ", Max[wF]];
    Print["  max / total    : ", Max[wF] / Total[wF]];
    Print["  ESS            : ", N[Total[wF]^2 / Total[wF^2]]];
    topF = Reverse[Ordering[wF]][[;; 5]];
    Print["  top 5 sample idx, numV, |Aut|, |Aut_F|, weight, share:"];
    Do[Print["    ", i, "  numV=", numV[[i]], "  |Aut|=", aut[[i]],
       "  |Aut_F|=", autF[[i]], "  w=", wF[[i]],
       "  share=", N[wF[[i]] / Total[wF]]],
      {i, topF}];
    Print[""]],
  {p, {2, 3, 4}}];
