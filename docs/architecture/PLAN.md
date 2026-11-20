# Repo architecture mapping — plan (resume point)

Started 2026-11-20 on branch `claude/codebase-architecture-diagrams-03d0de`.
Goal: (1) understand every tracked file, (2) low-level diagram of the CURRENT
file-to-file flow (data/logs kept general), (3) low-level diagram of the IDEAL
workflow where an outside researcher clones from GitHub and regenerates data
and figures on their own machine.

## Steps (tick as done)

- [ ] 1. Inventory: one record per tracked file under `src/`, `ECGrav/`,
      `archive/`, `docs/`, root, `.claude/` (figures/ kept at dir level).
      Record = purpose, loads (Get/Needs/dot-source), reads (data globs),
      writes (data/figures/logs globs), env knobs, launched-by, status
      (production / validation / one-off / superseded / dead).
      Output: `docs/architecture/inventory.md`.
- [ ] 2. Current-state diagram: `docs/architecture/current.md` (Mermaid) +
      HTML artifact. Nodes = every src file, grouped by pipeline stage;
      edges = Get/launch (solid) and data artifact (dashed via data glob nodes).
- [ ] 3. Ideal-state diagram: `docs/architecture/ideal.md` — one entry point
      (e.g. `make`-like `run_all.wl` with stages), config file instead of env
      knobs, clear lib/ pipeline/ figures/ split, data either regenerated or
      downloaded (Zenodo), archive removed from the reproducibility path.
- [ ] 4. Publish both diagrams as one artifact page; commit docs/architecture.

## Status 2026-11-20
Steps 1–3 done: inventory.md + inventory_raw.json, current.md, ideal.md
(Mermaid, render on GitHub). HTML page `architecture.html` published at
https://claude.ai/artifact/2iHVGoZGk87tj14Nfo3VrQ (private). Mermaid syntax
was hand-checked; it was not machine-rendered locally.

Revision: the single giant charts were unreadable, so `current.md` is now an
overview plus 7 per-stage diagrams and `ideal.md` has 3 small views.
Rebuild the page with `python build_page.py` after editing either .md.

## Inventory workflow run
Run ID `wf_2614a8d1-ef8` (same Claude session only). Results journal:
`C:\Users\darth\.claude\projects\C--CombResearch--claude-worktrees-ecstatic-wiles-75960d\c49935f3-ce2d-46b6-97b1-bd3b76f5d854\subagents\workflows\wf_2614a8d1-ef8\journal.jsonl`
— each agent's JSON record is there even if the session dies.

## If interrupted
Read this file, check which of the outputs above exist, continue from the
first missing one. Workflow inventory groups: (A) core libs + enumeration,
(B) IS compute + Figure 2 render, (C) MH chains + q=10, (D) ECGrav campaign +
3-way, (E) non-src (ECGrav, archive, docs, root, figures layout).
