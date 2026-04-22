(* Measures wall-clock cost of sampling + per-sample statistics for q=10.
   This is the relevant benchmark since we are NOT enumerating classes
   (theory-overlay dots are descoped). *)

Needs["ECGrav`"];

numVert[c_List] := Length[DeleteDuplicates[Flatten[c]]];
numFacets[c_List] := Length[c];

(* 1-skeleton graph from facet list *)
oneSkeleton[c_List] := Module[{verts, edges},
  verts = DeleteDuplicates[Flatten[c]];
  edges = DeleteDuplicates[Flatten[Subsets[#, {2}] & /@ c, 1]];
  Graph[verts, UndirectedEdge @@@ edges]
];

num1VConnComps[c_List] := Length[ConnectedComponents[oneSkeleton[c]]];

num2VConnComps[c_List] := Module[{g = oneSkeleton[c]},
  (* 2-vertex-connected components = biconnected components minus isolated vertices *)
  Length[KVertexConnectedComponents[g, 2]]
];

largestCompRatio[c_List] := Module[{g = oneSkeleton[c], cc, nv},
  cc = ConnectedComponents[g];
  nv = VertexCount[g];
  Max[Length /@ cc] / nv // N
];

(* k-graph: vertices = (k-1)-simplices, edges = pairs of (k-1)-simplices sharing a facet *)
kPathConnComps[c_List, k_Integer] := Module[{subs, pairs},
  (* for each facet, collect its (k-1)-faces = size-k subsets *)
  subs = Sort /@ Flatten[Subsets[#, {k}] & /@ c, 1] // DeleteDuplicates;
  pairs = Flatten[
    Table[
      With[{faces = Sort /@ Subsets[f, {k}]},
        Subsets[faces, {2}]
      ],
      {f, c}
    ], 1] // DeleteDuplicates;
  Length[ConnectedComponents[Graph[subs, UndirectedEdge @@@ pairs]]]
];

statsFor[c_List] := <|
  "numV" -> numVert[c],
  "aut" -> PureComplexAutomorphismGroupOrder[c],
  "autF" -> PureComplexFacetAutomorphismGroupOrder[c],
  "n1v" -> num1VConnComps[c],
  "n2v" -> num2VConnComps[c],
  "lcr" -> largestCompRatio[c]
|>;

statsForWith2Path[c_List] := Append[statsFor[c], "n2p" -> kPathConnComps[c, 2]];
statsForWith3Path[c_List] := Append[statsFor[c], "n3p" -> kPathConnComps[c, 3]];

SeedRandom[42];
n = 100;

Do[
  Print["--- pq = ", {p, 10}, ", n = ", n, " ---"];
  tSample = AbsoluteTiming[
    sample = RandomVertexLabeledPureSimplicialComplex[{p, 10}, n];
  ][[1]];
  Print["  Sample draw: ", tSample, " s"];

  tStats = AbsoluteTiming[
    If[p == 2,
      stats = statsFor /@ sample,
      If[p == 3,
        stats = statsForWith2Path /@ sample,
        stats = statsForWith3Path /@ sample
      ]
    ];
  ][[1]];
  Print["  Per-sample stats (", n, " complexes): ", tStats, " s"];
  Print["  Per sample: ", tStats/n, " s"];
  Print["  Vertex range: ", {Min[#["numV"] & /@ stats], Max[#["numV"] & /@ stats]}];
  Print["  Median |Aut|: ", Median[#["aut"] & /@ stats]];
  Print["  Est. time for N=10000: ", N[tStats * 100], " s"];
  ,
  {p, {2, 3, 4}}
];

Print["Done."];
