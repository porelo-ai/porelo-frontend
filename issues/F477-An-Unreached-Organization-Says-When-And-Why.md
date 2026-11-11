# F477 — An Unreached Organization Says When And Why

```json
{
  "$schema": "issue-1.json",
  "id": "F477",
  "title": "An Unreached Organization Says When And Why",
  "state": "Implementing",
  "size": "S",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "A project page whose organization could not be reached says so, when it was read last, and, once Porelo names it, why, instead of only that its repositories could not be read."
}
```

**Why this size.** one source's reading of `porelo project show` and one page's head, no contract of its own.

**What must be true.** A person whose project page shows no repositories learns that the organization could not be
reached, when it was read last and why, so they know what to fix instead of trying again blind.

## Why

When Porelo cannot fetch the organization's repository, `porelo project show --json` answers from the last trusted
state, `"stale": true` with its `checked_at`, and the project's repositories as `cannot-say`, with no reason. The
page said only "Its repositories could not be read just now.", and the head repeated it.

## Plan

- `lib/src/app/porelo_organization_source.dart`, `readProject`: a `cannot-say` on a stale answer is worded as an
  unreached organization with the local time of `checked_at` (and its date when it is not today); a `checked_at`
  missing or unreadable says that Porelo does not say when. A `cannot-say` on a fresh answer keeps its sentence.
- `lib/src/ui/organization_project_pages.dart`: the page head says only "repositories not read"; the whole sentence
  stands once, above the list.
- Second step, once Porelo answers why: its `stale_why` (in `org` and `project show`) and the `why` of a
  `cannot-say` are shown verbatim beside the time; an older Porelo without them keeps the first step's sentence.
- No test of its own for the wording: a stale answer was never shown as a good state, and the guard that an unread
  list never counts as empty (`test/ui/organization_project_pages_test.dart`) still holds.

## Acceptance

- Against a Porelo that cannot fetch the organization, the project page names the organization as unreached and the
  time it was read last; once Porelo names the reason, that too.

## To be checked

- The field names Porelo gives the reason, once it serves them.
