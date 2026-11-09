# F451 — Leftovers Of The Planning Board

**Status:** Idea.

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
- **A daemon that answers the board once, without streaming,** keeps its board shown without saying it is not live;
  whether the board should say so is the operator's choice.
- **The planning commands in the finder** (open a story or an issue, move an issue, open its web page, save, undo) are
  registered with no test that fails when they are not.
- **The start dialog's machine choice** has a test that fails only as a type error when the old field returns, not on
  the behavior it guards: a rejected machine change leaving the old working state selected.

## Open questions

- Should a board read from a daemon that does not stream say that it is not live?
