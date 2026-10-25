# F188 — One Expandable List Row For Every List

**Status:** Implementing.
**Size:** L - new shared row widget in `lib/src/ui/`, `lib/src/ui/tokens.dart`, `lib/src/ui/projects_page.dart`, `lib/src/ui/forges_page.dart`, `lib/src/ui/machines_page.dart`, and `lib/src/ui/attention_view.dart`.

**What must be true.** *Projects*, *Forges*, *Machines*, and *Needs you* all use one shared list-row
component: a single line of one fixed height with an icon, name, small state label, the main action
for the current state on the right, and an expand arrow at the far right. Clicking the row opens its
detail page; only clicking the expand arrow opens or closes the in-place details below the line
(showing full state, messages, and further actions, pushing rows below down).

## Plan

- **Order.**
  - Build this issue before [F187](README.md#f187), which uses this shared row component for all
    *Needs you* and *Recently resolved* rows.
- **Where it is today.**
  - `ProjectsPage` (`lib/src/ui/projects_page.dart`), `ForgesPage` (`lib/src/ui/forges_page.dart`),
    `MachinesPage` (`lib/src/ui/machines_page.dart`), and `AttentionView`
    (`lib/src/ui/attention_view.dart`) each build their own row widgets (`Card` + `ListTile` on
    *Projects*, *Forges*, and configured *Machines*; a multi-line custom `Card` in
    `_HostPreparationRow` on *Machines*; and multi-line custom cards on *Needs you*).
  - On `MachinesPage`, a server in preparation (`_HostPreparationRow`, lines 199–316) is a tall
    multi-line card showing the step text, time note, waiting stop banner, and a `Wrap` of buttons,
    whereas a configured machine row above or below it is a `ListTile` with a subtitle and a
    trailing `PopupMenuButton`.
- **Steps.**
  1. Define the fixed single-line row height token in `lib/src/ui/tokens.dart` (`Sizes`) and create a
     shared stateful widget (for example `ExpandableListRow` in `lib/src/ui/expandable_list_row.dart`)
     with:
     - A fixed-height top bar containing: leading `Icon`, primary title (`Text`, single line with
       ellipsis), compact state label (`Text` or chip), optional primary action button on the right,
       and a trailing expand/collapse `IconButton` (`Icons.expand_more` / `Icons.chevron_right`).
     - Separate hit targets: tapping the row body invokes `onOpen` (navigating to the project, forge,
       machine, or item detail page), whereas only tapping the expand arrow `IconButton` toggles the
       expanded section below the line.
     - An animated or direct in-place body below the bar that renders the expanded details (full
       state description, messages, and secondary action buttons) and pushes subsequent rows down.
  2. Migrate `ProjectsPage` (`lib/src/ui/projects_page.dart`) to `ExpandableListRow`: clicking a
     project row opens the project page (`onSelect`), the main action stands on the right, and the
     arrow expands the project's machine/repository summary and secondary commands.
  3. Migrate `ForgesPage` (`lib/src/ui/forges_page.dart`) to `ExpandableListRow`: clicking a forge
     row opens the forge view, the primary action stands on the right, and the arrow expands the
     forge's status and secondary actions.
  4. Migrate both configured machine rows and `_HostPreparationRow` in `MachinesPage`
     (`lib/src/ui/machines_page.dart`) to `ExpandableListRow` so a server in preparation and a ready
     server have the exact same collapsed height: the single line shows the server's icon, name,
     short state label (such as *In preparation*, *Needs you*, *Interrupted*, or *Connected*), the
     main action for that state (*Open terminal*, *Go on*, *Protocol*), and the expand arrow; the
     expanded body holds the step details, time note, and secondary actions (*Take it down*,
     *Remove*).
  5. Wire `ExpandableListRow` into `AttentionView` (`lib/src/ui/attention_view.dart`) so
     [F187](README.md#f187) uses the exact same row geometry and expand-arrow behavior.
- **Tests, their harm, red first.**
  - *Harm:* clicking the expand arrow accidentally triggers `onOpen` and navigates away from the
    list instead of expanding the row in place, or clicking the row body expands instead of opening
    the detail page.
  - In a widget test `test/expandable_list_row_test.dart`, render `ExpandableListRow` with an
    `onOpen` callback and expanded content: assert that tapping the row title calls `onOpen` without
    expanding the body, and tapping the expand arrow reveals the expanded content without calling
    `onOpen`. Break the separate hit target on the arrow first and watch the test fail.
  - Words, colors, and layout get no test.

## Acceptance

- Every row in *Projects*, *Forges*, *Machines* (both in-preparation and configured servers), and
  *Needs you* has the same collapsed single-line height and layout: icon, name, short state label,
  main action, and expand arrow.
- Clicking a row's body opens its detail page; clicking only the expand arrow opens or closes the
  row's details in place, pushing the rows below down.
