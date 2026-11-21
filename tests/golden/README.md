# Golden reference

Phase 0 safety net from `docs/architecture/implementation-plan.md`. It lives
in the code checkout and is tracked in git. It is never written through
`$CombRoot`.

## golden/derived

Values derived from the data stored today: numV marginals, L1 tables, iso
counts, stat-column sums, and the binned data behind each figure panel.
Each value is computed by a verbatim copy of the code in the script that
produces it. A refactor must reproduce every record **exactly** (`===`) from
the same inputs, on the same Wolfram build.

- `golden_common.wl`: shared helpers and the section contract.
- `golden_derived.wl`: the runner, `write` or `check`. It runs each section
  in its own process.
- `sections/*.wl`: one file per section, returning
  `<|"inputs" -> {...}, "records" -> <|...|>|>`.
- `lib/*.wl`: helpers shared between sections.
- `derived/<section>.wxf`: the frozen records, plus the SHA-256 of every
  input and the `$Version` that made them.

```powershell
wolframscript -file tests\golden\golden_derived.wl list
wolframscript -file tests\golden\golden_derived.wl check
wolframscript -file tests\golden\golden_derived.wl check validate compare
```

Exit codes: 0 all records match, 1 a record differs, 2 an input or golden
file is missing, or the run failed.

When a check fails, read which part changed:

- **"INPUTS CHANGED"**: the data changed (a rerun, a restore), not the code.
  Re-baseline that section on purpose:

  ```powershell
  $env:COMB_FORCE = "1"; wolframscript -file tests\golden\golden_derived.wl write <section>
  ```

  Then say so in the commit.
- **Inputs the same but a record differs**: the code changed the result.
  That is a refactor bug unless the change was intended.

The q=10 sections (`q10_p2`, `q10_p3`, `q10_p4`) each load one merged stats
file (0.3 to 1.4 GB). Run them one at a time, not alongside other heavy
jobs.

### Run checks in a scratch root

Checks only read the data store, but the refactored code under test may
write outputs. Give it a scratch root so it never touches the shared store:

```powershell
wolframscript -file tools\dev\make_check_root.wl C:\scratch\combcheck golden
$env:COMB_ROOT = "C:\scratch\combcheck"; wolframscript -file tests\golden\golden_derived.wl check
```

`make_check_root.wl` copies files up to 300 MB. It hard-links larger ones
(the q=10 merged stats), which are inputs that nothing rewrites. Never run
`concat_samples.wl` against a check root.

A check root has no `ECGrav-upstream`, so any script that loads ECGrav
aborts there, and wolframscript still exits 0. Point it at the shared clone
first: `$env:COMB_ECGRAV_DIR = "C:\CombResearch\ECGrav-upstream"`.

### What is frozen, and known-bad inputs

The store is frozen **as it is** on 2026-11-20. The five pre-fix vertex MH
chains are in it, and records built from them carry `knownBad`. A
`storedSummaryMatch` field compares the recomputation with the summary WXF
the original script wrote. Any `False` is a data finding, and
`docs/architecture/provenance.md` explains it.

Left out on purpose:

- the iid p-value in `validate_mh_vs_truth.wl` (drawn with no seed);
- wall times and creation dates;
- the ECGrav side of `validate_counts_vs_truth.wl`;
- panels drawn from fresh MH or ECGrav chains: `render_ecgrav_compare`,
  `render_uniformity_check`, and panels A/B of `render_sampler_progress`.
  Their draws depend on the ECGrav version, so they belong in
  golden/quick.

## golden/quick (not built yet)

This needs the `quick` profile from Phase 2/3 (`config/cells.wl`, `run.wl`).
When it exists:

- the quick profile's outputs must match truth exactly;
- samplers must stay within tolerance (L1 vs truth < 0.05), because ECGrav
  keeps changing.
