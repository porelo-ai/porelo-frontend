# F451 — Leftovers Of The Planning Board

**Status:** Implementing.
**Size:** S - the mock's board brought under the interface's rule for a story's state, and a story's move
taking the issues that rule names, in the mock and the client alike.

**What must be true.** What fitting the planning board to the daemon's interface ([F446](README.md#f446) to
[F449](README.md#f449)) left unbuilt is kept in one place until the operator places each part: in an issue of its own,
in a sprint, or dropped. Each point came from that fit, and gets no reading of its own.

Each point is to be checked against the code before it is fixed.

## How it stands

- **The mock's board contradicts the interface's rule for a story's state.** The interface reports a story in the
  earliest open state of its issues, in workflow order; six stories of the mock's board stand in a state that rule
  cannot give (ST292 in Backlog with all its issues in Implementing, and ST72, ST15, ST27, ST5, ST193), so a saved
  move of one of them lands elsewhere than a person expects from the mock.
- **Which issues a story's move takes** is chosen, in the mock and in the client, as those in the story's state, not
  as the least advanced ones; the two agree only while the board follows the rule above.
- Placed by the operator (2026-11-10): the two points above are built here; a board without streaming saying it is
  not live went to [F467](README.md#f467); the finder's planning commands and the start dialog's machine choice went
  to [F450](README.md#f450).

## Plan

- Bring the mock's board (`lib/src/mock/`, its planning stories) under the rule: each story in the earliest open state
  of its issues, in workflow order; the six named stories fixed, and a test over the whole mock board that fails for
  any story that breaks the rule.
- A story's move takes the least advanced issues, as the interface says, in the mock and in the client
  (`lib/src/client/planning.dart` and the board's move), not those in the story's state.
- Red first for each: the rule test over the mock board, and a move of a story whose issues stand in two states.

## Acceptance

- Every story of the mock's board stands where the rule puts it; a saved move of a story with issues in two states
  moves the least advanced ones, in the mock and the client; each test seen red first.
