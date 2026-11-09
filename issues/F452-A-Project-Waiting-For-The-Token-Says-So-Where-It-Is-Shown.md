# F452 — A Project Waiting For The Token Says So Where It Is Shown

**Status:** Backlog.
**Size:** M - one state read already (`HostProgress`), said in four places that read it differently today, the token
action offered beside each, and the placing dialog opened again.

**What must be true.** Where a host reports a project as waiting for the person's token, every place that shows the
project on that machine says it waits for the token, why, and offers *Give it my … token…* right there; it is never
called carried while the host reports a waiting state.
- The project's row under the organization's *Projects*, the machine's page of the project and each repository row of
  it say "waits for your … token" with the host's own reason where it gives one, never "carried" or "not carried".
- *Give it my … token…* stands beside that sentence in each place, not only on the organization's page of the
  machine, and says why the host asks: it keeps no token, and each repository it takes needs its read key and its
  first copy.
- The placing dialog, opened again for a project whose placing waits, is not grey: it says the placing waits for the
  token and offers the same action.

## Plan

- `lib/src/app/host_progress.dart` already reads `waiting-for-token` (`HostProjectProgress.state`, `waitsForToken`);
  `lib/src/ui/machine_tree.dart` `repositoryOnTheMachine` takes the project's state before its repository rows, so a
  waiting project says it waits on each row instead of "carried: not read" or "not carried: …".
- The organization's project row (`lib/src/ui/shell.dart`, the *Projects* section) and the machine's project page take
  the same words from one function beside `repositoryOnTheMachine`, and offer the token command
  (`organization_host_pages.dart` has it for the machine page today) as a `Command` in `commands.dart`.
- The placing dialog (`host_dialog.dart`, `_knownProjectStates`) answers a waiting project with the token action
  rather than a disabled form.
- Red first: a feature scenario where the host answers `waiting-for-token` for a placed project, which today reads
  "carried by this machine" on the project page and must not.

## Acceptance

- With the mock host answering `waiting-for-token`, the project row, the machine's project page and each repository
  row say it waits for the token and offer the action; seen to fail: any of them saying carried.
- After the token is given and the host answers `carried`, the waiting words and the action are gone.
