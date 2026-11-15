# F595 — Leftovers Of ST365, ST367 And ST368

```json
{
  "$schema": "issue-1.json",
  "id": "F595",
  "title": "Leftovers Of ST365, ST367 And ST368",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 85,
  "blockedBy": [],
  "covers": "What the finished issues of ST365, ST367 and ST368 left open, gathered for the operator to place: a sign-in row that outlives a sign-in made elsewhere, starts kept for the window's life, a planned task's name and rework stage, a central chip's cut reason, the stage hand-in tried against the planner itself."
}
```

**What must be true.** What [F586](README.md#f586) to [F591](README.md#f591) and [F594](README.md#f594) left unbuilt or unchecked is kept in one place until the operator
places each part: in an issue of its own, in a sprint, or dropped. Each point is checked against the code again
before it is fixed.

## Points

### From [F586](README.md#f586), a start refused for a sign-in

- A *Needs you* sign-in row resolves only on its own sign-in's `signedIn` answer: one made elsewhere (the start form,
  a terminal at the machine) leaves it until it is pressed or its machine is forgotten.
- The row's key is the machine's name, so a machine renamed leaves its row until the machine is forgotten.
- The row's `ask()` runs on the backend of the start that was refused, which may be stale after a reconnect.
- The row's LOOPBACK note (made at the machine or carried with *Import from this computer…*) has no test.
- Accepted: a restart's words, and an operation's other than the start form's, name the agent by the name the machine
  sent, not its label; neither `FleetModel` nor `Operations` holds the machine's agents list.

### From [F587](README.md#f587), a sign-in being started

- With Agent Core: whether `AgentSignInStart` can name its step (image build, container start) or stream it, so the
  panel says the machine's own step instead of the likely one; until then the sentence names both.

### From [F588](README.md#f588), a start from the board

- `_plannedStarts` in the shell is never pruned: an id per start pressed on the board, for the window's life.
- A start's final reply's output and steps may be said twice in its operation where the machine repeats them there.
- A planner-ordered start that fails after it said something also shows as a failed operation under *Needs you*,
  beside the report's own problem.
- The *Start work* dialog staying over the window while it waits on Start: its own issue,
  [F597](README.md#f597).
- Test gaps: the planner told once is asserted only through the stand-in's count of starts; a start that answered
  without starting (`_Said`) has no operation test; a discussion's operation title is not asserted; the live read of
  the operations has no test of its own.
- Where *0 tasks there* in the status line comes from: no string in `lib` says it, so it is the planning screen's own
  or another line; and which project it counts, the board's or the discussion's.
- With Agent Planner: the board's *In analysis* for a running discussion.

### From [F589](README.md#f589), a planned task says what it works on

- Whether the task should carry the issue's name instead of the repository's (*pi*): that name is Start's, so Agent
  Core and Agent Planner say whether an order names one; the window then shows it.
- With Agent Core: whether a task that may not push names a `buildReader` at all.
- *Rework*: whether an order can say that its task reworks, so its row says *rework* rather than *implementing*.
- The running view's tabs (`lib/src/ui/running_view.dart`) carry no offer and read only as tabs; a role this build
  does not know reads as *Implementing*.
- Test gaps: `cause-works-on`, a stage with a build already, an older entry's row.

### From [F590](README.md#f590), a repository's central chip

- The reason of *cannot say* stands only in the chip, cut with an ellipsis at 30% of the row, so it is read whole only
  in its tooltip; the row has no details for it.
- The chip is placed by `WindowSize.chipBeside` on the card's width, not `chipBesideWords` on the row's, so in a
  narrower pane the title can be cramped beside it; no overflow is expected.
- *Bring it to central…* in a row's menu is the project's command: it names no repository and brings every one that
  is ahead.
- An ahead chip on `default`, or on a project where `saysOfCentral` is false, shows with no command in its menu.

### From [F591](README.md#f591), a planned stage hands its result to the planner

- The window was tested against a stand-in of the agreed answers, not porelo-planner's hand-in route itself
  (PL141); once that route is in the pinned planner, a test against it.
- Agent Core's issue number for Start's `readOnly` and `given` (porelo `4cb4a81bb`, B791) cited where the hand-in is
  described.

### From [F594](README.md#f594), a story finished on the board

- Yellows of the reading: on the old pin the scenario stops at the warning, so the issues left in *Review* are not
  seen red alone (a later step guards them); the step checks the screen's exact sentence, so a rewording there breaks
  it; the CHANGELOG says *Review* where the screen takes the last work rule's done state, *Review* in the shipped
  workflow.
