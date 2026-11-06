# F421 — An Action On A Machine Shows It Works, And Answers Where It Was Pressed

**Status:** Accepted (operator, 2026-11-06).
**Size:** M - one shared button for an action that asks a machine, holding its own working state and its answer
beside it, and the pages' actions moved onto it; [F413](README.md#f413) and [F420](README.md#f420) are two of its cases.

**What must be true.** Every press in the window that asks a machine and waits - fetching, starting work, reading the
gate, putting a project on a machine, connecting, giving a token, refreshing - shows from the press to the answer that
it works (the button disabled with a small ring, and what it waits for), and its answer, done or refused, stands
beside the button pressed, where the person looks. A new action gets both by using the shared button, as [F408](README.md#f408) makes
folding the list section's own.

## Why

The operator's walk on the rehearsal VM (2026-11-06): after *Fetch now* on rehearsal's page the text it shows
afterwards could not be seen. Before it, *Start work* ([F413](README.md#f413)) and the gate view
([F420](README.md#f420)) gave no sign of working for many seconds.

## Where it lacks today

- **Machine page** (`organization_host_pages.dart`): *Fetch now*, *Connect*, *Take it off*/*Put it back* (`_read`,
  `_connect`, `_act`) set one `_acting` flag that disables every button and shows "Waiting for the machine…" in the
  status lines, but no ring on the button pressed; a refusal goes to `_refusal` at the page's head, above the
  connection and the buttons - out of sight once the page is scrolled to them. *Start work* (`_startWork`) has no
  working state at all ([F413](README.md#f413)); *Give it my token…* and *Make a backup key* only their own words.
- **Organization page** (`organization_page.dart`): a change (*Put it on a machine…*, add, remove) is said by
  `OrganizationChangeMark` at the page's head and "Adding…" on the row; the dialog closes at the press.
- **Gate view** (`gate_view.dart`): nothing while it reads ([F420](README.md#f420)).
- **Machines and machine page** (`machines_page.dart`, `machine_details_page.dart`): a refresh shows only in the status
  line at the window's foot.

## Plan

- A shared `AskingButton` (`lib/src/ui/asking_button.dart`): takes the label, what it waits for, and an action
  answering null or refusal words; it disables itself and shows a small ring with its words while the action runs,
  and its answer under itself until the next press. One press at a time: a second press while it runs sends
  nothing.
- The machine page's buttons, *Start work* ([F413](README.md#f413)'s case), *Give it my token…*, *Fetch now*, *Connect*, the
  organization page's row actions and the forges' sign-in move onto it; the page-head `_refusal` stays only for what
  no button asked.
- The gate view takes [F420](README.md#f420)'s reading line.
- **The test that goes red first:** `AskingButton` with an action not yet answered shows its ring and words and is
  disabled, a second press calls nothing, and the refusal shows under it; and the machine page's *Fetch now* refused
  shows its words beside the button. It guards a person who presses again, or leaves, because nothing answered where
  they pressed.

## Acceptance

- Every listed action shows its working state and answers beside itself.
