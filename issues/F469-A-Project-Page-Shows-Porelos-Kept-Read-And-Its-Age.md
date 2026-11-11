# F469 — A Project Page Shows Porelo's Kept Read And Its Age

```json
{
  "$schema": "issue-1.json",
  "id": "F469",
  "title": "A Project Page Shows Porelo's Kept Read And Its Age",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 3,
  "blockedBy": [],
  "covers": "A project page shows Porelo's kept read at once with its age, then the fresh one; nothing old shown as just read."
}
```

**Why this size.** the age and `stale` of a project's read and the organization's read shown, one fresh read with
`--refresh` after the kept one, and their tests.

**What must be true.** A project's page and the organization's pages show Porelo's kept read at once, saying how old
it is, and replace it with a fresh read when that comes; nothing old is shown as if it were just read.
- Serves porelo-project's *A click answers at once* (story ST304), after [F362](README.md#f362): there the window
  shows what it already holds while Porelo's read of the project takes 2.5 to 2.7 s.
- Porelo's coming change answers both reads at once from what it last checked, with its age and `stale`, refreshes in
  the background, and waits for a fresh read only when asked with `--refresh`. No field changes its meaning.
- Today the window reads `stale` from `porelo org` but not from `porelo project show`. Once Porelo answers from its
  kept state, a project's page that ignores it would show an old read as fresh.

## How it stands

- `porelo project show` and `porelo org` answer the kept state at once with `stale`, `checked_at`, `age_seconds` and
  `stale_why` (`kept` while the check runs after the answer), and wait for a check only with `--refresh`.
- A source that can, `ReadsKeptFirst` (`PoreloOrganizationSource`), hands the kept state to the page before it asks
  with `--refresh`; the project's page shows it at once as a last read, with no change offered, saying when it was
  checked last, and the checked read replaces it; the organization's model shows a kept state only where no checked
  one is shown. A kept project is shown at once only where its members' cards are known, never as "not yet".
- A read that stays stale, its check refused or timed out, says so on the project's page with when and why; a
  Porelo that answers no `stale` is asked once, as before.


- Read the age and `stale` of `porelo project show` into the project's view, as `porelo org`'s are read.
- A project's page and the organization's pages: show the kept read with its age where it is stale or old, then ask
  again with `--refresh` and replace it; a refused fresh read leaves the kept one, said as such.
- A Porelo without `--refresh` is asked as today, by the version it reports or the refusal it gives.
- Red first: a kept read shown with its age and then replaced by the fresh one; a stale project read never shown as
  just read; an older Porelo asked without `--refresh`.

## Acceptance

- Against the mock and live: a project's page shows the kept read at once with its age, and the fresh read replaces
  it; each test seen red first.
