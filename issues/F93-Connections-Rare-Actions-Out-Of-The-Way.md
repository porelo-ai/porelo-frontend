# F93 — Connections: Its Rare Actions Out Of The Way

**Status:** Estimated.
**Size:** S - one view and its steps change; the wizard and `Connections` stay as they are.

**What must be true.** A machine's Connections shows which key or token the machine reaches each
outside address with, and its rarely needed actions, "Add a connection" and "Forget", sit in the
view's ⋮ instead of in the everyday view.

## Why

Binding a machine to a project at a forge makes those entries itself. "Add a connection" is needed
only for a repository on no forge set up here (an own git server with a token), "Forget" only to stop
a machine using a key for an address.

## Plan

- **The view.** In `lib/src/ui/connections_view.dart`, `ConnectionsView.build` drops the
  `FilledButton.icon` keyed `add-connection` and gives `PaneHeader` a ⋮ beside the close button: a
  `PopupMenuButton<String>` as `forgeMenu` in `lib/src/ui/forges_page.dart` builds it, with "Add a
  connection" (disabled while `Connections.busy`) and one "Forget <address>" entry per connection.
- **The row.** `_ConnectionRow` loses its trailing `TextButton.icon` keyed `forget <match>`; it keeps
  what it shows: the kind, the purpose, where the value is kept, and whether it is there.
- **The callbacks stay.** `onAdd` and `onForget` keep their types, so `_ShellState` in
  `lib/src/ui/shell.dart` (which builds `ConnectionsView` and owns `_addAConnection`) is not touched.
- **The steps.** `test/features/step/i_add_a_connection_to.dart` and
  `i_forget_the_connection.dart` open the ⋮ first; `adding_a_connection_is_offered.dart` and
  `the_connections_of_the_machine_are_open.dart` look for the menu entry, not the button.
- **The wizard's last step.** Where the new-machine wizard ends in this view, it opens "Add a
  connection" at once; whoever needs none closes it. `adding_a_machine.feature`'s step "adding a
  connection is offered" then finds the open dialog.
- **Red first.** A new scenario in `test/features/connections.feature`, "adding and forgetting are
  in the view's menu, not in the view": it finds no `add-connection` and no `forget ...` outside the
  open menu, then adds and forgets through it. The existing add and forget scenarios must stay green
  once the steps go through the menu.

## Acceptance

- "Add a connection" and "Forget" are reached from the view's ⋮ and work as before; the view itself
  offers neither. Seen to fail: a scenario in `test/features/connections.feature` that finds either
  action in the view outside the ⋮, or cannot add or forget a connection through the ⋮.

## To be checked

- With many connections, is one "Forget <address>" entry per connection in the ⋮ right, or a
  chooser behind one "Forget…" entry? (Agent Frontend's)
