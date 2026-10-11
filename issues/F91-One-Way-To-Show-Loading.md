# F91 — One Way To Show Loading

**Status:** Analyzed.
**Size:** M - one small shared widget, but eleven views and a held answer for each in the test
backend; no contract changes.

**What must be true.** Every view that reads something when it opens shows, the same way, that it is
reading and what, so a person never takes an empty view for a finished one.

## The shape

- A progress bar at the view's top with one sentence of what is being read ("Reading vm's
  connections…"), until the answer is there; then the answer, or why there is none.
- The forge's page already shows it this way. The views still to go through: Connections, a machine's
  page, the gate, backups, what a project may reach, Messages, Agents, the vault, the start form, a
  project's machines and keys at its forge, the Default dialog.

## Plan

- **The widget.** A `Reading` widget in a new `lib/src/ui/reading.dart`: a `LinearProgressIndicator`
  and one sentence under it, keyed `reading`, shown while a flag says so. It is lifted out of
  `_ForgePageState.build` in `lib/src/ui/forges_page.dart` (the `forge-loading` block), which then
  uses it; that keeps the forge's scenarios as the first proof nothing changed.
- **What "reading" is, per view.** Most models already carry `busy` (`Connections`, `Backups`,
  `Egress`, `AgentInventory`, `Vault`, `Gate`, `StartWork`, `MachineBinding`), but `busy` is also
  true while an action runs. Each view shows `Reading` only before its first answer: a `loaded`
  flag or a null list, as `ForgeConnection.loaded` does today, added to a model where it is missing.
- **The views, in order.** `ConnectionsView` (`connections_view.dart`), `BackupsView`
  (`backups_view.dart`, its own `busy && taken.isEmpty` branch), `EgressView` (`egress_view.dart`),
  `MessagesDialog` (`messages_view.dart`, "Asking the machine…"), `AgentsView`
  (`agents_view.dart`), `VaultView` (`vault_view.dart`, `busy && state == null`), `GateView`
  (`gate_view.dart`, its centred `CircularProgressIndicator`), `StartWorkDialog`
  (`start_work_view.dart`), `ProjectForgeDialog` (`project_forge_view.dart`), `DefaultDialog`
  (`default_view.dart`, its `_busy`), and the machine's page, `_ShellState._machineArea` in
  `lib/src/ui/shell.dart`. Each gets its sentence, naming the machine or project.
- **Holding an answer back.** `FakeBackend` in `test/features/support/world.dart` holds only
  credential checks today (`holdingChecks`). It gets a general hold: a step "the machine answers
  only when told", which parks every read in a `Completer`, and the existing "the machine
  answers" releases them. The hold for the root's setup (`holdRoot`) stays as it is.
- **Red first.** In `test/features/connections.feature`: "while the machine is asked, the view says
  it is reading its connections": hold, open, find `reading` and the sentence, release, find the
  list and no `reading`. Then one scenario of the same shape in each view's own feature file. The
  "one widget" criterion is checked by those scenarios all finding the same key, not by reading
  the source.

## Acceptance

- One shared widget shows the reading, and each of the views above uses it. Seen to fail: a view in
  the list that builds its own progress or none.
- Each view, its answer held back, shows the progress and its sentence, then the answer once it comes.
  Seen to fail: a scenario per view that holds the answer back and finds no progress or no sentence,
  or still finds the progress after the answer came.

## Open questions

- Dialogs (`MessagesDialog`, `DefaultDialog`, `StartWorkDialog`, `ProjectForgeDialog`) have no
  pane header: the bar sits at the top of the dialog's content, not under a title bar. Is that
  the same "way" the shape asks for? (the operator's)

## To be checked

- A machine's page is `_ShellState._machineArea` over `FleetModel`, whose `busy` is true on every
  `FleetModel.refresh` not marked quiet: is the bar shown only on the first read after opening, or
  on each of those refreshes too? (Agent Frontend's)
