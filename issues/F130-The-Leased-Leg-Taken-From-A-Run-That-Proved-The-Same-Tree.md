# F130 — The Leased Leg Taken From A Run That Proved The Same Tree

**Status:** Implementing; built against [BT15](https://github.com/porelo-ai/porelo-buildtools/blob/main/issues/README.md#bt15)'s `proven-legs` in `f28a690`, Review once a Build on `main` has run it.
**Size:** S - one step that asks `porelo-release proven-legs` before the leased job, that job run
only when the answer is no, and one Build on `main` seen to skip it and one seen to run it.

**What must be true.** A Build on `main` whose tree a run of this repository already proved, with
"Test against a leased machine" green, from a push or a dispatch at most 24 hours ago, rents no
machine and says which run it took the leg from. Every other Build, every tag and every dispatch runs the leg.

## Why

[BT15](https://github.com/porelo-ai/porelo-buildtools/blob/main/issues/README.md#bt15) gives every repository one command that answers whether a run already proved the same tree with
its legs green. This repository's Build rents one machine for its leased leg on every push to
`main`. A push whose tree a run already proved, such as a squash merge of a branch that was
up to date, rents again for nothing.

Publish takes nothing from the leg. It takes `packages` from the `build` job and `windows` from
the Windows job, and a snapshot does not wait on the leg already. So skipping the leg leaves
Publish whole.

## Plan

- **A first step in the `integration` job's place:** a small job, on the runner, asks
  `porelo-release proven-legs --repository porelo-ai/porelo-frontend --tree "$(git rev-parse HEAD^{tree})" --jobs "Test against a leased machine"`
  and passes `proven` on as its output.
- **The question** is asked on a push to a branch only; a tag and a dispatch, which is how a whole
  run is forced, skip it.
- **The `integration` job** runs unless that says `proven=yes`. When it is
  skipped, the first job's summary carries the command's line: "legs taken from run <id>, tree
  <hash>, <age> old".
- **Publish's condition** keeps `needs.integration.result == 'success'` for a release, so a tag
  never publishes on a proof.

## Acceptance

- **A Build on `main` with a proven tree** skips the leased job, names the run it took the leg
  from, and publishes its own snapshot.
- **A Build on `main` with a new tree** runs the leased job as today.
- **A tag and a dispatch** run the leased job whatever the answer.
