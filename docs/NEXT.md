# Next session — handoff

> Written 2026-04-23, right before a 4-day unattended sampling run. Overwrite when that run lands and you resume work.

## What's running right now

A detached PowerShell process is driving `src/run_parallel.ps1` with:

- `N = 10000000` samples per p
- `RUNTAG = batch3`
- `pList = {3, 4}` (p=2 dropped — ESS is healthy there, and freeing those 8 subkernels lets p=3 and p=4 split all 16 threads cleanly)

Logs: `logs/compute_p3_batch3.log`, `logs/compute_p4_batch3.log`. Each writes WXF chunks into `data/` (400 chunks of 25k samples per p). Consolidation at the end produces:

- `data/p3q10_n10000000_batch3_stats.wxf` + `..._complexes.wxf`
- `data/p4q10_n10000000_batch3_stats.wxf` + `..._complexes.wxf`

Projected wall-clock (from batch2 rates):

- p=3: ~41 h — finishes around hour 41 of 96
- p=4: ~76 h — finishes around hour 76 of 96, leaving ~20 h margin on the 96 h budget

## Pipeline changes landed in this session

Commit `e671bda` on `main`:

1. **CSV → WXF.** `pure_simplicial_compute.wl` now writes two WXF files per chunk (`..._chunk_k_stats.wxf` + `..._chunk_k_complexes.wxf`) atomically; consolidation produces final Associations with metadata (`headers`, `rows`, `p`, `q`, `n`, `runTag`, `createdAt`). Weights kept as exact rationals — no float-to-string lossiness.
2. **Raw complexes saved.** New `..._complexes.wxf` per session holds the facet-lists (what Dr. Betre asked for). Stats can be re-derived from these later if `statsFor` ever changes.
3. **Concat updated** (`src/concat_samples.wl`) — merges all `..._*_stats.wxf` and their complex siblings into `p{p}q10_merged_{stats,complexes}.wxf`.
4. **Renderer** (`src/render_all_figures.wl`) — loads WXF if present, falls back to legacy CSV for backwards compat.
5. **Migrator** (`src/migrate_csv_to_wxf.wl`) — one-shot already run against the 6 legacy CSVs in `data/`; they now have matching `..._stats.wxf` files (no complexes — those weren't saved historically).
6. **Parallel driver** (`src/run_parallel.ps1`) — `$env:COMB_PLIST` override; default is now `"3,4"`.

Smoke-tested end-to-end at N=200 (two batches, concat, readback). All good.

## When you return

1. Check `tail -5 logs/compute_p{3,4}_batch3.log` — both should end in `Done.` If p=4 is still running, let it finish (resumable from chunk level; at most 11 min of work redone on interrupt).
2. Merge the new data into the running totals: `wolframscript -file src/concat_samples.wl` — writes `p{3,4}q10_merged_{stats,complexes}.wxf` from all batches available.
3. Re-render: `wolframscript -file src/render_all_figures.wl`. Point `sampleSize` / `sampleTag` at the merged file if you want figures from the full combined data (edit `src/render_all_figures.wl:33-34`).
4. Check ESS. At q=10 p=4 it almost certainly still collapses — the heavy-tailed IS problem isn't fixed by more samples. But with 12M p=4 samples total (0.5 + 1.5 + 10) you'll have the largest dataset the reweighting hack can ever meaningfully produce, which will matter for the eventual sampler-swap discussion with Dr. Betre.

## If something goes wrong

- **Out of disk:** each final WXF pair is ~3 GB (p=3) to ~4 GB (p=4). Disk was 95 GB free at launch. Transient chunk files peak at ~6 GB.
- **Crash mid-run:** just re-run `powershell -ExecutionPolicy Bypass -File src/run_parallel.ps1` with `$env:N=10000000; $env:RUNTAG=batch3` — checkpointing resumes at the first missing chunk for each p.
- **Need to kill:** `Get-Process wolframscript,WolframKernel,wolfram | Stop-Process -Force` from PowerShell. Partial chunks are atomic (tmp+rename) — no corruption.

## Still pending (unchanged from prior handoff)

- Dr. Betre's reply to the ESS / sampler-swap email. Nothing to do until then.
- Add him as a GitHub collaborator once he sends his username.
