# F446 — The Stories Of A Project On A Planning Board

**Status:** Implementing, against a stand-in for the daemon; blocked by the daemon's planning part on the wire.
**Size:** M - a new place with its page, one part of the contract read and watched, its models, the mock daemon and the
fake backend taught it, and a feature file; no logic of the window's own.

**What must be true.** Under *Planning*, beside *Work* and *Needs you*, the operator sees every story of a project on a
board: one column per phase, the phase's states inside it, each story as a card in its state, the most important
first. The board is what the machine says, read and kept current from it alone; the window works out no state of its
own.

## What it builds against (in words)

- The machine that carries a project's planning answers, on its owner-only socket, the project's workflow (its states,
  each waiting, working or closed, in their order, and its phases, each naming its states), its stories (id, title,
  state, priority, what it gains, the operator's test, its issues each with id, repository, title, state, size, blocked
  by and a web link, the work running on it, and the story's own web link), and a revision. A watch on the stories
  answers the whole board first and again on every change, whoever made it.
- A story's state is the machine's, computed from its issues; the window never derives it.
- *Reading* is a working state of its own, entered by the machine on its own when the build before it is done; an
  issue in Reading or Reworking carries the number of reading rounds it has been through.

## Plan

- `lib/src/app/shell_model.dart`: `Section.planning('Planning')`, a place of its own; `lib/src/ui/shell_rail.dart`: its
  row after *Needs you*, with the count of stories in a working state; `lib/src/ui/shell.dart`: the page for it.
- `lib/src/client/planning.dart` (new): `PlanState`, `PlanPhase`, `PlanStory`, `PlanIssue`, `PlanWork`, read leniently as
  the models in `models.dart` are (a field the machine does not send stays unsaid, never a default that reads as an
  answer); `lib/src/client/porelo_client.dart`: the workflow, the stories and the watch on them (`_callMore`, as `Watch`).
- `lib/src/app/planning_board.dart` (new), a `ChangeNotifier`: one project's board from the watch, the columns and their
  folding, the priority filter, the search, and whether closed states show; kept per project so a second project does
  not reset the first.
- `lib/src/ui/planning_view.dart` (new), after the design: phases as columns, a phase's states inside it with its
  working states on top and tinted, each with its count; a phase or one state folds to its number and the priority
  marks of its cards; cards show id, priority chip, title, the round where an issue of it is in Reading or Reworking (*reading 2 of 3*), the work running on it (agent, mode, since) or *nobody at work* where its
  work was stopped and it still stands in a working state, the number of
  issues, the share in Review or Finished as a bar, and unfold to their issues; the closed states (Finished,
  Rejected) hidden behind *Show Finished and Rejected (n)*; a project chooser where more than one project has
  planning, read from the machine shown, or from another watched machine that offers that project's planning; a
  priority filter and a search over id and title. Priority order then number, as the design.
- An older machine without the planning part: the page says the machine does not offer planning, and nothing else.
- `lib/src/mock/mock_daemon.dart` and the fake backend in `test/features/support/world.dart` answer the part with the
  design's stories, so `dart tool/mock_daemon.dart` shows the board.
- `test/features/planning_board.feature`: the columns in the workflow's order, a renamed state shown by its new name,
  a story in its state sorted by priority, a folded phase with its count, closed states hidden and shown, a change
  from elsewhere arriving on the watch. First red: a story shown in a column the machine did not put it in.

## Acceptance

- A card whose issue is in Reading or Reworking shows its round as the machine counts it, never one the window counts.
- The board shows each story in the state the machine says, in the workflow's order, sorted by priority; a state
  renamed in the workflow shows by its new name without a new window.
- A change made elsewhere shows within one answer of the watch, without a reload.
- With a machine that does not offer planning, the page says so and offers nothing that would call it.

## Open questions

- None. Any machine that offers a project's planning may serve its board; work runs where the operator starts it
  (the operator, 2026-11-09).

## To be checked

- The method and field names once the daemon's part is served.
