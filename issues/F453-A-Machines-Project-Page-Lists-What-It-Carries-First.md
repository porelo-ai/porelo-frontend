# F453 — A Machine's Project Page Lists What It Carries First

```json
{
  "$schema": "issue-1.json",
  "id": "F453",
  "title": "A Machine's Project Page Lists What It Carries First",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 10,
  "blockedBy": [],
  "covers": "A machine's project page lists the carried repositories first and folds the rest with their count; no raw host word; forge names shown as such; zero tasks said as 0."
}
```

**Why this size.** one list sorted and folded, the host's raw words replaced, the forge's names shown as such, one count
said as zero.

**What must be true.** A machine's page of a project shows the repositories it carries first and folds the rest under
one line that counts them, so the few placed there are not buried among the project's others.
- The carried repositories stand first; the others fold under "not carried here (N)".
- No raw word of the host reaches the page: "not carried: not-carried" reads "not carried here".
- A repository is named as the project names it, with the forge's name of it beside where they differ
  (`pi`, on the forge `porelo-pi`).
- Right after carrying, a repository with no task says "0 tasks", not "tasks: not reported", where the machine was
  asked and answered.

## How it stands

- `lib/src/ui/machine_tree.dart`: `carriedOnTheMachine` says, from the same reading as the row's words, whether the
  machine carries a repository; the project's page lists the carried ones first, then those nobody said of, and folds
  those it does not carry under *Not carried here (N)*. Where it carries none, the list stays whole and open.
- The host's `not-carried` reads "not carried here"; a word of a later host is still shown as it comes.
- **Not built: "0 tasks" for a repository only the host names.** The machine's daemon does not list such a repository,
  so its work is not counted, and a guard holds that work nobody counted never reads as none; it reads as counted once
  the daemon lists the repository with its counts.
- **Not built: the forge's name beside the project's.** Neither the daemon's list (`Repository.name`) nor the host's
  answer (`repository` per row in `host_progress.dart`) carries a repository's forge name; showing it needs one of them
  to answer it.
- Order, folding and wording only: no new test, as the rules ask for what only reads wrong.

## Acceptance

- The mock host carrying three of eighteen: the three stand first, the fifteen fold under one row with their count;
  seen to fail: a raw host word on the page.
