(* sampler_mh.wl
   Exploratory Metropolis-Hastings sampler over isomorphism classes of pure
   simplicial complexes (q facets, purity p).

   STATUS: prototype. Math reviewed and small-example-verified (p=2 q=2 on
   [N=4] gives uniform iso-class marginal, see comments below). NOT
   benchmarked vs IS at q=10, NOT in the production pipeline. Written
   2026-04-29 in response to docs/email_betre_post_batch3.md item 1, pending
   Dr. Betre's reply. See docs/PIPELINE.md for the IS sampler this is
   trying to replace at q=10 p∈{3,4}.

   ============================================================================
   PRIOR ATTEMPT (replaced by this file 2026-04-29)
   ============================================================================
   First draft canonicalized state to "vertex labels in first-appearance order,
   no unused labels." That broke detailed balance: the canonicalization
   collapses different vertex-labelings of the same iso class to a variable
   number of canonical forms (e.g. for the (p=2,q=2) path iso class, 3
   labelings collapse to 2 canonical forms; for "two disjoint edges," 3
   labelings collapse to 1). This makes P_marg([iso class]) ∝ 1/c([Y]) where
   c is an irregular collapse factor. Empirically the chain at p=4 q=10
   reported E[numV] ≈ 10 vs true π_U mode ~18 (verified via IS at 12M).

   This rewrite uses a FIXED ambient label set [N] with N = q·p (the maximum
   possible numV for a pure complex with q facets at purity p). Every state
   is a vertex-labeled complex on a subset of [N]; "unused" labels are simply
   not in any facet. Detailed balance holds without canonicalization.

   ============================================================================
   STATE
   ============================================================================
   A state is a sorted list of q distinct sorted p-element subsets of [N],
   where N = q·p. The active vertex set V(X) = ⋃ F_i ⊆ [N]. numV(X) = |V(X)|.

   ============================================================================
   TARGETS
   ============================================================================
     unlabeled (uniform on iso classes):
       π_U(X) ∝ |Aut(X)| · (N - numV(X))!
     facet (uniform on facet-labelings, marginal on iso classes):
       π_F(X) ∝ |Aut(X)| · (N - numV(X))! / |Aut_F(X)|
     vertex (uniform on vertex-labeled, sanity check):
       π_V(X) ∝ 1

   Verification of unlabeled target via marginal calculation:
     For iso class [Y] with numV([Y]) = k, the number of vertex-labeled
     states on [N] with iso class [Y] is C(N, k) · k!/|Aut(Y)|. Each such
     state has π_U ∝ |Aut(Y)| · (N-k)!. So
       π_U_marg([Y]) ∝ C(N,k) · k!/|Aut(Y)| · |Aut(Y)| · (N-k)! = N!.
     Constant in [Y]. ✓ Uniform on iso classes.

   Hand-verified small example (p=2, q=2, N=4):
     iso "path" (numV=3, |Aut|=2): 12 states · 2·1! = 24 total mass.
     iso "matching" (numV=4, |Aut|=8): 3 states · 8·0! = 24 total mass.
     Equal. ✓

   ============================================================================
   PROPOSAL
   ============================================================================
   From X with active set V(X) ⊆ [N]:
     1. Pick i ∈ {1,...,q} uniformly.
     2. Pick F' uniformly from p-subsets of [N] not equal to any F_j (j ≠ i).
     3. Form Y as X with F_i replaced by F', then re-sort.
   Proposal density q(X→Y) = (1/q) · 1/(C(N,p) - (q-1)). Symmetric in (X,Y).

   ============================================================================
   ACCEPTANCE RATIO
   ============================================================================
   With symmetric proposal:
     α(X→Y) = min(1, π(Y)/π(X))

   For target unlabeled:
     π(Y)/π(X) = [|Aut(Y)|/|Aut(X)|] · [(N-numV(Y))!/(N-numV(X))!]
   For target facet:
     π(Y)/π(X) = [|Aut(Y)|/|Aut(X)|]
                 · [|Aut_F(X)|/|Aut_F(Y)|]
                 · [(N-numV(Y))!/(N-numV(X))!]
   For target vertex:
     π(Y)/π(X) = 1   (chain reduces to RW on vertex-labeled states)

   Factorial ratio (N-mY)!/(N-m)! depends on Δm = mY - m ∈ {-p, ..., p}:
     Δm =  0  →  1
     Δm = +1  →  1/(N-m)
     Δm = +2  →  1/((N-m)(N-m-1))
     Δm = -1  →  N-m+1
     etc. Bounded by polynomial factor in N.
*)

Needs["ECGrav`"];

(* =============================================================== *)
(* Helpers                                                          *)
(* =============================================================== *)

numActive[facets_List] := Length[DeleteDuplicates[Flatten[facets]]];

(* Sample a uniform random p-subset of [N] excluding the supplied list.
   Rejection sampling. *)
randomSubsetExcluding[n_Integer, p_Integer, forbidden_List] := Module[
  {F, attempts = 0, maxAttempts = 1000},
  While[attempts < maxAttempts,
    F = Sort[RandomSample[Range[n], p]];
    If[!MemberQ[forbidden, F], Return[F]];
    attempts++];
  RandomChoice[Complement[Subsets[Range[n], {p}], forbidden]]];

(* For computing |Aut| we hand the chain state straight to the ECGrav
   functions. They operate on facet lists over arbitrary integer labels;
   the value of |Aut| is iso-invariant so the choice of labels doesn't
   matter. *)

(* =============================================================== *)
(* MH step                                                          *)
(* =============================================================== *)

(* Returns {newState, acceptedQ, ΔnumV, alpha}.
   nMax (rather than N) to avoid shadowing built-in N (numerical conversion). *)
mhStep[X_List, p_Integer, q_Integer, nMax_Integer, target_String] := Module[
  {m, mY, i, otherFacets, Fnew, Y,
   autX, autY, autFX, autFY, factRatio, piRatio, alpha, u},

  m = numActive[X];
  i = RandomInteger[{1, q}];
  otherFacets = Delete[X, i];
  Fnew = randomSubsetExcluding[nMax, p, otherFacets];
  Y = Sort[ReplacePart[X, i -> Fnew]];
  mY = numActive[Y];

  (* (nMax-mY)!/(nMax-m)! computed safely for any Δm ∈ [-p, p]. *)
  factRatio = Which[
    mY == m,  1,
    mY > m,   1 / Product[nMax - m - j, {j, 0, mY - m - 1}],
    mY < m,   Product[nMax - mY - j, {j, 0, m - mY - 1}]];

  Switch[target,
    "unlabeled",
      autX = PureComplexAutomorphismGroupOrder[X];
      autY = PureComplexAutomorphismGroupOrder[Y];
      piRatio = (autY / autX) * factRatio,
    "facet",
      autX  = PureComplexAutomorphismGroupOrder[X];
      autY  = PureComplexAutomorphismGroupOrder[Y];
      autFX = PureComplexFacetAutomorphismGroupOrder[X];
      autFY = PureComplexFacetAutomorphismGroupOrder[Y];
      piRatio = (autY / autX) * (autFX / autFY) * factRatio,
    "vertex",
      piRatio = 1,
    _,
      Print["unknown target: ", target]; Abort[]];

  alpha = Min[1, N[piRatio]];
  u = RandomReal[];
  If[u < alpha,
    {Y, True, mY - m, alpha},
    {X, False, mY - m, alpha}]
];

(* =============================================================== *)
(* Initialization                                                   *)
(* =============================================================== *)

(* Embed a vertex-labeled sample (active labels in {1..k}) into [nMax] as the
   first k labels. Other labels in [nMax] are unused. *)
initialState[p_Integer, q_Integer, nMax_Integer, seed_Integer] := Module[
  {complex, sorted},
  SeedRandom[seed];
  complex = First[RandomVertexLabeledPureSimplicialComplex[{p, q}, 1]];
  sorted = Sort[Sort /@ complex];
  sorted];

(* =============================================================== *)
(* Chain runner                                                     *)
(* =============================================================== *)

Options[runMHChain] = {burnIn -> 0, thin -> 1, seed -> 12345, verbose -> True};

runMHChain[p_Integer, q_Integer, target_String, numIter_Integer,
           opts:OptionsPattern[]] := Module[
  {bIn, th, sd, vrb, NN, X, traceLen, trace, accepts = 0, deltas,
   step, idx, t0, t1},

  bIn = OptionValue[burnIn];
  th  = OptionValue[thin];
  sd  = OptionValue[seed];
  vrb = OptionValue[verbose];

  NN = q * p;
  X  = initialState[p, q, NN, sd];

  If[vrb,
    Print["MH chain: p=", p, " q=", q, " nMax=", NN,
      " target=", target, " numIter=", numIter,
      " burnIn=", bIn, " thin=", th]];

  t0 = AbsoluteTime[];

  (* Burn-in. *)
  Do[
    step = mhStep[X, p, q, NN, target];
    X = step[[1]];
    If[step[[2]], accepts++],
    {bIn}];
  If[vrb && bIn > 0,
    Print["  burn-in done: ", bIn, " steps, accept rate ",
      ToString[NumberForm[N[accepts/bIn], {4, 3}]]]];

  (* Sampling. *)
  accepts = 0;
  deltas = ConstantArray[0, numIter];
  traceLen = Quotient[numIter, th];
  trace = ConstantArray[Null, traceLen];
  idx = 0;
  Do[
    step = mhStep[X, p, q, NN, target];
    X = step[[1]];
    If[step[[2]], accepts++];
    deltas[[k]] = step[[3]];
    If[Mod[k, th] == 0,
      idx++;
      trace[[idx]] = X],
    {k, numIter}];

  t1 = AbsoluteTime[];

  If[vrb,
    Print["  sampling done: ", numIter, " steps in ",
      ToString[NumberForm[t1 - t0, {6, 1}]], " s"];
    Print["    accept rate    : ",
      ToString[NumberForm[N[accepts/numIter], {4, 3}]]];
    Print["    Δ numV counts  : ", Counts[deltas]];
    Print["    trace length   : ", traceLen]];

  <|
    "p" -> p, "q" -> q, "N" -> NN, "target" -> target,
    "numIter" -> numIter, "burnIn" -> bIn, "thin" -> th, "seed" -> sd,
    "trace" -> trace,
    "acceptRate" -> N[accepts/numIter],
    "deltaNumVCounts" -> Counts[deltas],
    "wallSeconds" -> (t1 - t0)
  |>
];

(* =============================================================== *)
(* Diagnostic: integrated autocorrelation time                      *)
(* =============================================================== *)

integratedAutocorrTime[x_List] := Module[{n, mu, var, c, k, sum},
  n = Length[x];
  mu = Mean[N[x]];
  var = Variance[N[x]];
  If[var == 0., Return[<|"tau" -> Infinity, "ess" -> 0|>]];
  sum = 0.5;
  k = 1;
  While[k < n - 1,
    c = Mean[(x[[1 ;; n - k]] - mu) * (x[[1 + k ;; n]] - mu)] / var;
    If[c <= 0, Break[]];
    sum += c;
    k++];
  <|"tau" -> sum, "ess" -> N[n / (2 sum)], "lagsUsed" -> k|>
];

(* =============================================================== *)
(* Smoke test main                                                  *)
(* =============================================================== *)

If[$InputFileName =!= "" && !TrueQ[$smokeTestSkip],
  Module[{result, numVTrace, ac},
    Do[
      Print["==========================================="];
      result = runMHChain[p, 10, "unlabeled", 5000, burnIn -> 1000];
      numVTrace = numActive /@ result["trace"];
      ac = integratedAutocorrTime[numVTrace];
      Print["    τ_int(numV)   : ",
        ToString[NumberForm[ac["tau"], {6, 2}]],
        "  (lagsUsed=", ac["lagsUsed"], ")"];
      Print["    effective N   : ", Round[ac["ess"]],
        " of ", Length[numVTrace]];
      Print["    numV mean/std : ",
        ToString[NumberForm[Mean[N[numVTrace]], {5, 2}]], " / ",
        ToString[NumberForm[StandardDeviation[N[numVTrace]], {5, 2}]]],
      {p, {2, 3, 4}}];
    Print["==========================================="];
    Print["smoke test done."]]];
