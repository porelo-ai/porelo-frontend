# F451 — Leftovers Of The Planning Board

**Status:** Review.
**Size:** S - the mock's board brought under the interface's rule for a story's state, and a story's move
taking the issues that rule names, in the mock and the client alike.

**What must be true.** What fitting the planning board to the daemon's interface ([F446](README.md#f446) to
[F449](README.md#f449)) left unbuilt is kept in one place until the operator places each part: in an issue of its own,
in a sprint, or dropped. Each point came from that fit, and gets no reading of its own.

Each point is to be checked against the code before it is fixed.

## Plan

- Bring the mock's board (`lib/src/mock/`, its planning stories) under the rule: each story in the earliest open state
  of its issues, in workflow order; the six named stories fixed, and a test over the whole mock board that fails for
  any story that breaks the rule.
- A story's move takes the least advanced issues, as the interface says, in the mock and in the client
  (`lib/src/client/planning.dart` and the board's move), not those in the story's state.
- Red first for each: the rule test over the mock board, and a move of a story whose issues stand in two states.

## How it stands

- Found: **the mock's board contradicted the interface's rule for a story's state.** The interface reports a story in
  the earliest open state of its issues, in workflow order; six stories of the mock's board stood in a state that rule
  cannot give (ST292 in Backlog with all its issues in Implementing, and ST72, ST15, ST27, ST5, ST193), so a saved
  move of one of them landed elsewhere than a person expected from the mock.
- Found: **which issues a story's move takes** was chosen, in the mock and in the client, as those in the story's
  state, not as the least advanced ones; the two agreed only while the board followed the rule above.
- Placed by the operator (2026-11-10): the two points above are built here; a board without streaming saying it is
  not live went to [F467](README.md#f467); the finder's planning commands and the start dialog's machine choice went
  to [F450](README.md#f450).
- Built: the mock's board puts each story in the earliest open state of its issues; the six stories above now hold
  issues that fit the state they stand in, so the features that drag them keep their columns. A story's move takes its
  least advanced issues - those in the earliest open state in workflow order, or in the earliest closed state when all
  are closed - in the mock's save (`lib/src/mock/planning_moves.dart`) and in the board's confirmation of a save
  (`PlanStory.leastAdvancedIssues`, used by `PlanningBoard.save`).
- Seen red first, all in `test/app/planning_moves_test.dart`:
  - *every story of the mock board stands in the earliest open state of its issues* failed listing the six stories,
    e.g. `ST292 in Backlog, rule says Implementing`.
  - *the stand-in moves a story by its least advanced issues, whatever state the story reports* failed with
    `Expected: ['IssueOne'] Actual: ['IssueTwo']`.
  - *a story move expects its least advanced issues to move, not those in its shown state* - at the time, after a save
    whose reread failed, the card showed its destination ahead of its issues; since the reading it keeps the
    machine's last answer - failed with `Actual: 'The machine did not confirm
    this destination.'`
- A reading of the change by another model found three faults to fix and three to consider; each taken was seen red
  first in `test/app/planning_moves_test.dart`:
  - Taken: an empty `moved` confirmed a story move whose issues were unreported or stood outside the workflow; the
    board now cannot tell those issues and keeps the move pending (red: `Expected: 'The machine did not confirm this
    destination.' Actual: <null>`, for each case).
  - Taken: the board applied a save's confirmations in staging order while the moves go out stories first, so an
    issue moved alone and with its story showed the story's destination (red: `['Done', 'Elsewhere']` instead of
    `['Elsewhere', 'Elsewhere']`); the mock now resolves every story move on the shown board and writes story moves
    before explicit issue moves (red: `['Done', 'Done']`), and refuses a story move with an issue outside the workflow
    (red: no refusal).
  - Taken: a saved story with issues showed its destination until the reread, though an issue could stay open; it now
    keeps the machine's last answer (red: `Expected: 'Ready' Actual: 'Done'`; the test of a move after a failed reread
    reads the same). A reread failing after a made save was caught as a save refusal, which said nothing and could
    mark saving unavailable; it now says so on the board (red: `Expected: not null Actual: <null>`).
  - Taken: a test of a story whose issues are all closed, over two closed states, in the mock and the board, and the
    exact stories the mock board test checks; both were green on the code, so each was seen red by breaking the code
    on purpose (only open issues, or the latest state) and dropping one story's issues from a copy of the data.
  - Taken: the mock's `StartStoryWork` and `ResolveIssueReading` now put the story where its issues place it before
    publishing (red: `Expected: 'Implementing' Actual: 'Reading'` and `Expected: 'Review' Actual: 'Reading'`). Which
    issues a start takes is left as it was, since the interface leaves that to the proposal.
  - Declined: the index's Size column for this issue stays `—`, as for every issue in Review.

## Acceptance

- Every story of the mock's board stands where the rule puts it; a saved move of a story with issues in two states
  moves the least advanced ones, in the mock and the client; each test seen red first.
