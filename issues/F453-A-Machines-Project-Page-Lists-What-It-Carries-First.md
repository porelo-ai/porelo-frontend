# F453 — A Machine's Project Page Lists What It Carries First

**Status:** Backlog.
**Size:** S - one list sorted and folded, the host's raw words replaced, the forge's names shown as such, one count
said as zero.

**What must be true.** A machine's page of a project shows the repositories it carries first and folds the rest under
one line that counts them, so the few placed there are not buried among the project's others.
- The carried repositories stand first; the others fold under "not carried here (N)".
- No raw word of the host reaches the page: "not carried: not-carried" reads "not carried here".
- A repository is named as the project names it, with the forge's name of it beside where they differ
  (`pi`, on the forge `porelo-pi`).
- Right after carrying, a repository with no task says "0 tasks", not "tasks: not reported", where the machine was
  asked and answered.

## Plan

- `lib/src/ui/machine_tree.dart`: `repositoryOnTheMachine` maps a known state word to words and drops the fallback
  `not carried: $state` for states the host names as not carried; the page's list sorts carried first and folds the
  rest in one expandable row.
- The forge's name comes from what the host answers for the repository; where the answer has none, the project's name
  stands alone.
- Red first: a widget test of the page with a host answering `not-carried` for fifteen repositories and `taken` for
  three, which today lists the raw word and the fifteen first.

## Acceptance

- The mock host carrying three of eighteen: the three stand first, the fifteen fold under one row with their count;
  seen to fail: a raw host word on the page.
