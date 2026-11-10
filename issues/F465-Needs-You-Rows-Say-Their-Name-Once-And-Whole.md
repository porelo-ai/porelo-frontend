# F465 — Needs You Rows Say Their Name Once And Whole

**Status:** Backlog.
**Size:** XS - a machine's row under *Needs you* named once, and a row's title given the width the row leaves free.

**What must be true.** Each row under *Needs you* names what it is about once and, where the window has room, whole.
- Seen live (2026-11-10, the move rehearsal against a rented host, window 1280x720): the row of this computer's
  machine, not answering, read "this machine · this machine". The row's title is the machine's name, and every row
  that is not a token's or a repository's gets " · <machine>" appended (`_row` in `lib/src/ui/attention_view.dart`).
- Seen live at the same size: the row of work waiting at the gate read "porelo-foo-project-gate-1: 1 c…", cut after
  two words, while about 50 pixels stood free between its state chip and its button, and the title column ended
  well before the chip. The title is one line with an ellipsis in a column that does not grow with the row
  (`ExpandableListRow`, `lib/src/ui/expandable_list_row.dart`).

## Plan

- `_row`: append the machine only where the title does not already name it (the silent machine's row, a machine's
  own rows), and never twice.
- `ExpandableListRow`: the title takes the width left after the state and the action, before it is cut; the full
  title stays in a tooltip where it is cut.
- Red first: a widget test of a silent machine's row (its title holds the machine's name once) and of a gate row at
  1280 wide whose title fits (it is not cut).

## Acceptance

- Under *Needs you* against the mock, a machine that does not answer reads its name once; a gate row's title at
  1280x720 is shown whole; both tests seen red first.
