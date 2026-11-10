# F466 — A Taken Repository Stays Carried While Another Waits

**Status:** Review.
**Size:** S - grown from XS at its reading: a repository the host has taken read as carried, and work started in it,
on every screen that says the project's wait, while the project waits for the token for another.

**What must be true.** Where a host waits for the person's token for one repository of a project, only that
repository's row says it waits; the repositories the host has taken read as carried, and work starts in them.
- Seen live (2026-11-10, machines-foo, foo-project with a new repository foo-3 the host waits for a central token
  for): the rows of foo-1 and foo-2, taken and up to date on the host with five tasks running in foo-1, read "waits
  for your GitHub token: foo-3: waits for a central token", and the window refused work in them. The rule from
  [F452](README.md#f452) took a waiting project as one the host takes nothing of, while the host reports each
  repository's own state.

## Plan

- `_standing` in `lib/src/ui/machine_tree.dart`: the project's wait applies to a repository the host has not taken;
  one it reports `taken` falls through to its carried words and starts work.
- Red first: a project waiting for the token with one repository taken and one waiting; the taken one is carried and
  starts work, the other waits.

## How it stands

- `_standing` in `lib/src/ui/machine_tree.dart` applies the project's wait only to a repository the host has not
  taken; one it reports `taken` keeps its carried words and starts work. Seen red: the taken repository read "waits
  for your GitHub token: docs: waits for a central token", as foo-1 did live.
- One code reading by another model found the wait applied to the whole project in five more places; all taken:
  the shell refused work in the project's taken repositories (`_waitWhyNot`, the project's page, new work and the
  machine's start); a repository with no central address or not carried here read as waiting; the organization's
  host page said a taken repository waits and kept its project from *Ready to work on*; every row's menu offered the
  token. Each fix has a test seen red first (`machine_own_pages_test`, `organization_host_pages_test`,
  `repository_on_the_machine_test`).
- Seen live on machines-foo with the first fix: the repository rows read carried for foo-1 and foo-2.

## Acceptance

- Against the mock and live: the taken repositories of a waiting project read carried, the waiting one reads its
  wait; the test seen red first.
