# Phase 6 deliverable: a GUI to discuss with Dr. Betre

Notes, 2026-11-23. Phase 6 (`implementation-plan.md`) starts by asking
Betre which pieces of `CombResearch/` he wants in ECGrav and in what form.
A working interface makes that conversation concrete: he can try each piece
on real cells instead of reading usage messages.

## Goal

One deliverable that:

1. shows each upstream candidate doing something useful;
2. makes the per-piece questions easy to answer ("this one, under this
   name, as a PR");
3. reuses what exists (package functions, the truth grid, validation
   results). No new algorithms.

## Recommended form: a Wolfram notebook with `Manipulate` panels

Betre works in Mathematica and ECGrav is a paclet, so a notebook is the
format he can open, run and edit. Working name `CombResearchExplorer.nb`,
in a new `demo/` folder. It would load:

- the package through `pipeline/common/combresearch.wl`;
- ECGrav through the shared clone.

On his machine it would load his installed ECGrav, which
`tools/dev/install_ecgrav_global.wl` already supports for notebooks.

Alternatives, if the notebook is not enough:

| Form | For | Against |
|---|---|---|
| Wolfram Cloud deploy (`CloudDeploy` of the same panels) | a link, nothing to install | cloud credits; live enumeration is slow there |
| Static HTML page from precomputed data | opens anywhere, easy to send | no live computation, so it does not show the code |
| Paclet documentation pages (`Documentation/`) | the form ECGrav functions ship in | more work; better done after Betre picks pieces |

**Decided (2026-11-23): a notebook.** Betre is on a Mac and we are on
Windows, so the notebook must work on both:

- Pure Wolfram Language: no PowerShell, no `.ps1` and no `RunProcess` of
  Windows tools.
- Find files relative to `NotebookDirectory[]` with `FileNameJoin`. Never
  use `C:\...` or the `comb_paths` git logic, because he will not have our
  worktrees or our store.
- Load ECGrav with plain `Needs["ECGrav`"]` (his installed paclet). Load
  CombResearch from a copy of the package shipped next to the notebook, or
  `PacletDirectoryLoad` of `CombResearch/`. The notebook must not depend on
  `pipeline/common/`, because that is our workflow code, not his.
- Ship the data the panels read inside the deliverable: the 9 truth WXFs
  (about 3 MB) and any small summary WXFs, either in a `demo/data/` folder
  or embedded in the notebook. Nothing reads `C:\CombResearch\data`.
- Parallel on by default, as in the pipeline: launch kernels once, load
  ECGrav and the package there (`ParallelNeeds`), fall back to serial only
  if that fails, with a **Parallel** checkbox to compare. Long calls inside
  `Manipulate` need `SynchronousUpdating -> False`.
- Before sending, test it on Windows with the global ECGrav paclet
  (`tools/dev/install_ecgrav_global.wl`) and with the store's `data/`
  temporarily out of reach. Ask Betre to open it once on the Mac and
  report anything that breaks.

## Panels (one per candidate piece)

| # | Panel | Uses | Upstream piece it argues for |
|---|---|---|---|
| 1 | **Enumerate**: pick (p, q) and Method (Automatic, Cheap, BLISS, McKay); show the iso-class count vs `$CombTruthIsoCounts`, the time, and a grid of representatives | `EnumerateUnlabeledPureComplexes`, `PureComplexCanonicalKey` | `Enumeration` (the clearest gap in ECGrav) |
| 2 | **Statistics**: pick a class, get its 12 statistics | `PureComplexStatistics`, `$PureComplexStatisticNames`, Betti and k-path helpers | `Statistics` |
| 3 | **Exact distributions**: pick a cell and a statistic; bars under π_V, π_F, π_U | the 9 truth WXFs (about 3 MB in total, can be embedded), `PureComplexTruthMarginal` | shows why exact enumeration matters |
| 4 | **Samplers vs truth**: draw N samples live (MH, ECGrav exact samplers, ECGrav MCMC) and overlay them on truth with the L1 distance | `PureComplexMHChain`, ECGrav `RandomUniform…`, `SampleHistogram`, `HistogramL1Distance` | `MHSampler`, and validates his samplers |
| 5 | **Mixing**: autocorrelation and ESS for our MH vs `RandomPureSimplicialComplexMCMC` on the unlabeled target | `IntegratedAutocorrelationTime`, `EffectiveSampleSize` | the MHSampler-vs-MCMC question; shows the correlated-samples finding (`docs/ecgrav_1.17_validation_note.md`) |

Optional sixth panel: q = 10 importance sampling, from the precomputed
`p{p}q10_is_stat_hists.wxf` (small). It shows `ISSampler` and the ESS
caveat. It stays optional until Betre says IS is in scope.

## Constraints to design around

- The point of the demo is experimental matching: live samples measured
  against exact truth (panel 4). The truth itself is exact enumeration;
  any cell can be enumerated from the notebook, but a cell like (4,5)
  (about 17 h with McKay) is run ahead of time, and the shipped truth
  files are the reference for the live panels.
- Keep sample sizes in panels 4 and 5 small enough for a few seconds per
  click, and say on the panel that the stored 200k chains are the real
  evidence.
- The notebook must not write into `data/`; it only reads.
- Our names: `PureComplex…` and `EnumerateUnlabeledPureComplexes`.
  ECGrav's: `…PureSimplicialComplex…`. Show ours as they are; renaming is
  one of the questions below.

## Questions for Betre (the reason for the demo)

1. Which pieces does he want: Enumeration, Statistics, MHSampler,
   ISSampler, Compare (L1/ESS helpers)?
2. In what form: PRs to `kassabetre/ECGrav` from a fork branch (our plan,
   developed with `COMB_ECGRAV_DIR`), or files he integrates himself?
3. Naming and options: his naming scheme for the new symbols. Are string
   option names (`"Parallel" -> False`) fine, or should they be symbols
   like his?
4. Tests: do our `.wlt` files (VerificationTest, ECGrav style) fit his
   test setup?
5. MCMC: does he want the correlated-samples finding as an issue or a fix
   PR? Does our MH replace, complement or stay out of
   `RandomPureSimplicialComplexMCMC`?
6. Does he want the demo notebook itself in ECGrav, as an example or
   tutorial?

## Steps once the form is agreed

1. Build panels 1-3 on stored data first. That is enough to show him.
2. Add panels 4-5, with live sampling at small N.
3. Smoke-check: open the notebook, evaluate every panel once in a fresh
   kernel (the Wolfram MCP server can read and run it), and check it
   writes nothing.
4. Send it to Betre with the questions above. Record his answers in
   `implementation-plan.md`, Phase 6 "Decisions".

## Open choices for us

- Scope for the first meeting: panels 1-3 only, or all five.
- Whether `demo/` is tracked here or lives only in the fork branch for
  ECGrav.

## End goal (2026-11-23): the notebook as the project's front end

The demo for Betre is step 1. The goal: run everything from a GUI in a
Mathematica notebook, with as much parallelization as possible, progress
bars on every long task, and compiled code where it pays.

1. **Demo panels** (above): in-notebook work against the truth grid,
   parallel on by default.
2. **Run control.** The notebook starts `run.wl` stages as background
   processes (`StartProcess`) instead of re-implementing them, so it
   inherits resume, skip rules, manifests, locks, `force` and profiles. A
   long job that crashes does not take the GUI down.
   - `run.wl status` and `dryrun` feed the store and plan tables.
   - A "jobs" setting maps to `run.wl ... jobs N`.
   - Parallelism stays where it is today: one process per cell x target
     (MH), per target (ECGrav), per p x batch (IS), and parallel kernels
     inside enumeration and IS.
3. **Progress bars.**
   - Per job: read from the logs, the same lines the `.ps1` monitors
     read. Stages that do not yet print a regular "k of n" line get one.
   - Overall: jobs done out of jobs planned.
   - In-notebook work: `Monitor` / `ProgressIndicator` with a shared
     counter across parallel kernels.
4. **Compilation.**
   - `FunctionCompile` needs no external C compiler, so it works the same
     on Betre's Mac. Old-style `Compile[..., CompilationTarget -> "C"]`
     needs Xcode or Visual Studio.
   - It only helps numeric and integer-array code: the MH inner loop
     (proposals, acceptance, vertex counts), the counting statistics, and
     maybe parts of the enumeration DFS bookkeeping.
   - Graph canonicalization, isomorphism tests and ECGrav's group orders
     cannot be compiled this way. The built-ins they rest on
     (`CanonicalGraph`, `MatrixRank`) are already compiled.
   - Profile each stage first. Then compile only the measured hot spots,
     and check each change against `golden_derived` and the truth grid.
