# F452 — A Project Waiting For The Token Says So Where It Is Shown

**Status:** Review.
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

## How it stands

- A project whose host answers `waiting-for-token` is never called carried: `repositoryOnTheMachine` in
  `lib/src/ui/machine_tree.dart` takes the wait after a repository the machine does not carry and before held and the
  daemon's "carried", and says "waits for your … token" with the host's reason; `hasNoAddress` reads "waits for its
  Git repository to be made". Work cannot start in it: `work.start`, `template.start` and `project.startAgents` are
  unavailable with that reason, and it is left out of *Ready to work on*.
- The organization's *Projects* row, *My projects*, the machine's *Projects*, the machine's page of the project and
  each repository row say the wait, and offer *Give it my … token…* bound to the host that waits, not the project's
  first host (`giveTokenCommand` in `lib/src/app/commands.dart`).
- A give runs once per host at a time (`lib/src/app/token_giving.dart`) and the host is asked again after it, so every
  page hears that it no longer waits. Progress is asked once of each connected host whose Machine Admin is the
  viewer, and again only after its connection came back.
- *Put it on a machine…* stays offered while a host of the viewer's waits, and opens the placing dialog with the wait
  and the token action instead of a grey form.
- Red first, by widget and unit tests rather than the feature scenario of the Plan: the waiting rows and their start
  refusal, the token bound to its own host, one give at a time with a re-read, and progress asked once and only by an
  admin; each seen red by breaking the code it guards.
- Two readings by another model, sixteen findings, all checked against the code and fixed with a test seen red first,
  but one: a page keeps the wait it last read when the host's connection drops, as losing contact keeps the last
  list everywhere in the window. Among them: no crash for a machine without a host card; no work, saved job or *New
  work* starts in a waiting project; progress is asked only by the host's Machine Admin, once per connection, joined
  where an ask is on its way, and again on *Refresh* from every page that shows it; a wait read is forgotten once the
  viewer is no longer its Machine Admin; the placing dialog hears a token given from it.
- Not tested on its own: the waiting words going after a give, which follows from the re-read; to be seen in
  the window against a host in the move's live leg.

## Acceptance

- With the mock host answering `waiting-for-token`, the project row, the machine's project page and each repository
  row say it waits for the token and offer the action; seen to fail: any of them saying carried.
- After the token is given and the host answers `carried`, the waiting words and the action are gone.
