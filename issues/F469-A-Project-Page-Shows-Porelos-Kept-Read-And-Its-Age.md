# F469 — A Project Page Shows Porelo's Kept Read And Its Age

**Status:** Backlog; blocked by Porelo answering `porelo project show` and `porelo org` at once from its kept, checked
state with its age and `stale`, and reading fresh with `--refresh`, released on the hosts the window reaches.
**Size:** S - the age and `stale` of a project's read and the organization's read shown, one fresh read with
`--refresh` after the kept one, and their tests.

**What must be true.** A project's page and the organization's pages show Porelo's kept read at once, saying how old
it is, and replace it with a fresh read when that comes; nothing old is shown as if it were just read.
- Serves porelo-project's *A click answers at once* (story ST304), after [F362](README.md#f362): there the window
  shows what it already holds while Porelo's read of the project takes 2.5 to 2.7 s.
- Porelo's coming change answers both reads at once from what it last checked, with its age and `stale`, refreshes in
  the background, and waits for a fresh read only when asked with `--refresh`. No field changes its meaning.
- Today the window reads `stale` from `porelo org` but not from `porelo project show`. Once Porelo answers from its
  kept state, a project's page that ignores it would show an old read as fresh.

## Plan

- Read the age and `stale` of `porelo project show` into the project's view, as `porelo org`'s are read.
- A project's page and the organization's pages: show the kept read with its age where it is stale or old, then ask
  again with `--refresh` and replace it; a refused fresh read leaves the kept one, said as such.
- A Porelo without `--refresh` is asked as today, by the version it reports or the refusal it gives.
- Red first: a kept read shown with its age and then replaced by the fresh one; a stale project read never shown as
  just read; an older Porelo asked without `--refresh`.

## Acceptance

- Against the mock and live: a project's page shows the kept read at once with its age, and the fresh read replaces
  it; each test seen red first.
