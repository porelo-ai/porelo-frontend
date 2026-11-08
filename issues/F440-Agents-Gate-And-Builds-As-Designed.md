# F440 — Agents, The Gate's Review And Builds As Designed

**Status:** Implementing.

**What must be true.** *Agents & providers* reads as one aligned list of agents with their facts, the gate's review
names who wrote and committed a push and its trailer, and a task's tile names each workflow of its commit with its own
verdict.

## Why

The third move (2026-11-08), findings 8, 14 and 16, decided by the operator that evening, with the designs *Agents and
providers* and *Third move findings, before and after* (pairs 14 and 16).

## Acceptance

- **Agents & providers** (finding 8): as the design draws it: a head with the count of agents and providers, a filter
  and *Providers on this machine*; a card with one row per agent (name, command and version, an *installed* chip, a
  fold). An unfolded agent shows its facts as label and value in two aligned columns (*Found at*, *Runs*, *Commits
  as*), then *Machines it needs* as allowed chips and *Asked for and refused* as refused chips, each with its note
  under the chips, left-aligned, and *What it fetches* with its sha256 shortened and a copy button. No centered label.
- **The gate's review** (finding 14): above the files, a card with *Commit*, *Author*, *Committer* and *Trailer* (the
  push's own lines), and a chip that says whether there is exactly one Assisted-by and no Co-Authored-By. Where the
  machine does not report them, the card says so instead of leaving them out.
- **Builds on a tile** (finding 16): one line per workflow of the commit, its name and its verdict (passed, running,
  not started, failed); "Build passed" only when every workflow has passed. Where the machine reports one verdict
  only, that verdict is named by its workflow.

## Size

M: M the agents' page, S the review card (with the push's fields as the machine reports them), S the workflows.
