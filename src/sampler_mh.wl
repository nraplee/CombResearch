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
     vertex (marginal-on-iso matches enumerate_truth's piVertex):
       π_V(X) ∝ 1 / C(N, numV(X))
       (Before 2026-05-14 the form was π_V ∝ 1, which gives a different
       distribution — uniform on labeled-in-[N] states — whose iso
       marginal includes an extra C(N, k) factor. See in-code comment
       at the vertex target Switch branch and validate_mh_vs_truth.wl.)

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

(* ===============================================================
   Proposal kernels (added 2026-04-29).

   All proposals are SYMMETRIC: q(X→Y) = q(Y→X). With symmetric q,
   Metropolis acceptance simplifies to min(1, π(Y)/π(X)).

   Each kernel returns {Y, deltaNumActive} — the proposed state and
   the change in numActive (0 for no-op).

   Benchmark results at p=4 q=10 / p=2 q=4 are summarized in
   docs/NEXT.md; tl;dr "global" remains the best for numV-mixing,
   "mixed" is comparable on accuracy and ~26% faster wall-clock.
   =============================================================== *)

proposeGlobal[X_List, p_Integer, q_Integer, nMax_Integer] := Module[
  {i, otherFacets, Fnew, Y, mOld},
  mOld = numActive[X];
  i = RandomInteger[{1, q}];
  otherFacets = Delete[X, i];
  Fnew = randomSubsetExcluding[nMax, p, otherFacets];
  Y = Sort[ReplacePart[X, i -> Fnew]];
  {Y, numActive[Y] - mOld}];

(* Local: change one vertex in one facet. Symmetric. *)
proposeLocal[X_List, p_Integer, q_Integer, nMax_Integer] := Module[
  {i, j, vNew, Fi, FNew, Y, mOld},
  mOld = numActive[X];
  i = RandomInteger[{1, q}];
  j = RandomInteger[{1, p}];
  vNew = RandomInteger[{1, nMax}];
  Fi = X[[i]];
  If[MemberQ[Fi, vNew], Return[{X, 0}]];
  FNew = Sort[ReplacePart[Fi, j -> vNew]];
  If[MemberQ[Delete[X, i], FNew], Return[{X, 0}]];
  Y = Sort[ReplacePart[X, i -> FNew]];
  {Y, numActive[Y] - mOld}];

(* Swap: exchange one vertex between two facets. Symmetric.
   WARNING: when used as the sole kernel, ergodicity is poor — at p=2
   most swaps yield states in the same iso class as the input. Useful
   only as a component of a mixture. *)
proposeSwap[X_List, p_Integer, q_Integer, nMax_Integer] := Module[
  {i, k, j, l, a, b, Fi, Fk, FiNew, FkNew, otherFacets, Y, mOld},
  mOld = numActive[X];
  i = RandomInteger[{1, q}];
  k = RandomInteger[{1, q - 1}];
  If[k >= i, k = k + 1];
  j = RandomInteger[{1, p}];
  l = RandomInteger[{1, p}];
  Fi = X[[i]]; Fk = X[[k]];
  a = Fi[[j]]; b = Fk[[l]];
  Which[
    a === b,        Return[{X, 0}],
    MemberQ[Fi, b], Return[{X, 0}],
    MemberQ[Fk, a], Return[{X, 0}]];
  FiNew = Sort[ReplacePart[Fi, j -> b]];
  FkNew = Sort[ReplacePart[Fk, l -> a]];
  If[FiNew === FkNew, Return[{X, 0}]];
  otherFacets = Delete[X, {{i}, {k}}];
  If[MemberQ[otherFacets, FiNew] || MemberQ[otherFacets, FkNew],
    Return[{X, 0}]];
  Y = Sort[ReplacePart[X, {i -> FiNew, k -> FkNew}]];
  {Y, numActive[Y] - mOld}];

(* Mixed: 50% local + 30% swap + 20% global. *)
proposeMixed[X_List, p_Integer, q_Integer, nMax_Integer,
             alphaLocal_:0.5, betaSwap_:0.3] := Module[{u},
  u = RandomReal[];
  Which[
    u < alphaLocal,            proposeLocal[X, p, q, nMax],
    u < alphaLocal + betaSwap, proposeSwap[X, p, q, nMax],
    True,                      proposeGlobal[X, p, q, nMax]]];

(* =============================================================== *)
(* MH step                                                          *)
(* =============================================================== *)

(* Returns {newState, acceptedQ, ΔnumV, alpha}.
   nMax (rather than N) to avoid shadowing built-in N (numerical conversion).
   kernel ∈ {"global", "local", "swap", "mixed"} selects the proposal kernel. *)
mhStep[X_List, p_Integer, q_Integer, nMax_Integer, target_String,
       kernel_String:"global"] := Module[
  {m, mY, Y, deltaM,
   autX, autY, autFX, autFY, factRatio, piRatio, alpha, u},

  m = numActive[X];
  {Y, deltaM} = Switch[kernel,
    "global", proposeGlobal[X, p, q, nMax],
    "local",  proposeLocal[X, p, q, nMax],
    "swap",   proposeSwap[X, p, q, nMax],
    "mixed",  proposeMixed[X, p, q, nMax],
    _, Print["unknown kernel: ", kernel]; Abort[]];

  (* If the proposal degenerated to a no-op (Y == X), accept trivially. *)
  If[Y === X, Return[{X, True, 0, 1.0}]];

  mY = m + deltaM;

  (* (nMax-mY)!/(nMax-m)! computed safely for any Δm ∈ [-p, p]. *)
  factRatio = Which[
    deltaM == 0, 1,
    deltaM > 0,  1 / Product[nMax - m - j, {j, 0, deltaM - 1}],
    deltaM < 0,  Product[nMax - mY - j, {j, 0, -deltaM - 1}]];

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
      (* 2026-05-14 fix: cancel the ambient-set embedding multiplicity
         C(nMax, k). Before this fix, vertex target was π_V(X) ∝ 1,
         which is uniform on vertex-labeled-in-[nMax] states. Its
         marginal over iso class [Y] is C(nMax, k)·k!/|Aut(Y)| where
         k = numV(Y). That's NOT enumerate_truth.wl's piVertex, which
         marginalizes to k!/|Aut(Y)| (intrinsic, no ambient).
         Validation at (3,5) showed L1 = 0.85 against truth.
         Setting π_V(X) ∝ 1/C(nMax, numV(X)) makes the marginal
         match: marginal[Y] ∝ C(nMax,k)·k!/|Aut(Y)| · 1/C(nMax,k)
         = k!/|Aut(Y)|. The acceptance ratio is
           π(Y)/π(X) = C(nMax, m) / C(nMax, mY).
         Note: this means π_V is no longer uniform on labeled-in-[nMax]
         states — labeled states with larger numV get LESS weight. *)
      piRatio = Binomial[nMax, m] / Binomial[nMax, mY],
    _,
      Print["unknown target: ", target]; Abort[]];

  alpha = Min[1, N[piRatio]];
  u = RandomReal[];
  If[u < alpha,
    {Y, True, deltaM, alpha},
    {X, False, deltaM, alpha}]
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

Options[runMHChain] = {burnIn -> 0, thin -> 1, seed -> 12345,
  verbose -> True, kernel -> "global"};

runMHChain[p_Integer, q_Integer, target_String, numIter_Integer,
           opts:OptionsPattern[]] := Module[
  {bIn, th, sd, vrb, kn, NN, X, traceLen, trace, accepts = 0, deltas,
   step, idx, t0, t1},

  bIn = OptionValue[burnIn];
  th  = OptionValue[thin];
  sd  = OptionValue[seed];
  vrb = OptionValue[verbose];
  kn  = OptionValue[kernel];

  NN = q * p;
  X  = initialState[p, q, NN, sd];

  If[vrb,
    Print["MH chain: p=", p, " q=", q, " nMax=", NN,
      " target=", target, " kernel=", kn,
      " numIter=", numIter, " burnIn=", bIn, " thin=", th]];

  t0 = AbsoluteTime[];

  (* Burn-in. *)
  Do[
    step = mhStep[X, p, q, NN, target, kn];
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
    step = mhStep[X, p, q, NN, target, kn];
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
