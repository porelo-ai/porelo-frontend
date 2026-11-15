# F587 — A Sign-In Being Started Shows It Runs

```json
{
  "$schema": "issue-1.json",
  "id": "F587",
  "title": "A Sign-In Being Started Shows It Runs",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 13,
  "blockedBy": [],
  "covers": "While a machine starts an agent's sign-in, which the first time builds its login image, the sign-in panel shows a progress mark, what the machine does, the time so far and what to do if it does not answer, and the start waits as long as the machine may take, instead of one sentence beside a grey button."
}
```

**Why this size.** One panel and the sign-in model's start, a deadline of its own for one call, and their tests; no
contract change.

**What must be true.** A person who presses *Sign in* sees at once that the machine works on it and for how long, and
knows when and how to look further; a first sign-in on a machine is not cut off while its login image is built.

## Found

The operator's live test on a host (snapshot 0.5.1~snapshot.552), *Start work in porelo*, repository pi, Claude Code
2.1.311: after *Sign in*, the panel said only *Starting the sign-in to Claude Code on <host>…*, its
button grey, with no mark, step or time, for a long while, then went on.

## Plan

- **The wait**, read in the wire and the code: `AgentSignInStart` returns once the login container runs, and the
  first time that includes building the login image (`40-agent.varlink`); a second call while one is prepared
  returns once that one runs. `SigningIn.signIn` (`lib/src/app/agent_sign_in.dart`) sets `starting` around that one
  call; `SignInPanel` (`lib/src/ui/sign_in_panel.dart`) shows the sentence alone while `starting` and a
  `LinearProgressIndicator` only while `waiting`. The call is a single call (`PoreloClient.agentSignInStart`) under
  `VarlinkConnection.answerWithin`, 30 s: an image build that takes longer ends the start in this window as a
  failure although the machine goes on, and the next press joins the login being prepared.
- **Steps.**
  - `agentSignInStart` on a connection of its own under a deadline of its own, as `agentSignInWait` has, long enough
    for an image build (the wire names no bound; 15 minutes, said in the client's doc), so a first sign-in is not
    cut off.
  - `SignInPanel` while `starting`: the window's progress mark (`Sizes.mark`, `Sizes.spinnerStroke`), the sentence
    *<machine> is preparing the sign-in to <agent>; the first sign-in on a machine builds its login container, which
    can take a few minutes.*, the time so far (minutes and seconds, ticking), and after two minutes *If this does not
    move, <machine>'s log says why (Open the log).*, using the machine's log view the window already opens.
  - The press stays grey with why while it runs, as today; leaving the panel leaves the start to the machine, as
    leaving a waiting sign-in does.
- **Red first** (harm: a person thinks nothing happens and presses again or gives up; a first sign-in cut off as
  failed while the machine still builds): a widget test that a start the stand-in holds shows the mark, the
  sentence and a time that moves with the clock, and the log hint after two minutes; a model test that a start the
  stand-in answers after the single call's deadline still ends started; each seen red.

## Built

- `lib/src/client/porelo_client.dart`: `PoreloClient.signInStartWithin` (15 minutes, its doc says why: the first
  start builds the login image, for which the contract names no bound). `agentSignInStart` opens a connection of its
  own as a call that may wait long (`RelayUse.stream()`, as the wait does, so on Windows it takes a stream's place
  rather than one of a call's) and calls `AgentSignInStart` under that deadline instead of `answerWithin`;
  `MethodNotFound` still becomes `FeatureNotSupported`, `SignInRefused` still its own error.
- `lib/src/app/agent_sign_in.dart`: `SigningIn` takes an optional clock (the system's by default), notes when a
  start begins, and answers `startingFor`, the time the start that is out has run, null while none is.
- `lib/src/ui/sign_in_panel.dart`: `SignInPanel` is stateful; while `starting` it shows the window's progress mark
  (`Sizes.mark`, `Sizes.spinnerStroke`), the sentence of the plan, the time so far (*1 min 5 s so far.*), ticking
  every second through a timer that runs only while a start is out (as *Needs you* keeps its countdown moving), and
  from `SignInPanel.lookFurtherAfter` (two minutes) on *If this does not move, <machine>'s log says why.* Every other
  state, and the grey *Sign in* with its reason, is as before.
- **The log hint is words only**: the window has no view of a machine's own log (it opens a task's logs, by task
  name, and nothing of `porelod`'s), so there is no *Open the log* to reach from the panel. The stand-ins needed no
  change: the features' `FakeBackend` already holds a start (`signInStartHeld`), and the model test's backends
  answer at once.
- Guards, each seen red:
  - `test/client/agent_sign_in_test.dart` *a start is not cut by the deadline of a single call* (over the mock
    daemon, the level at which the deadline lives, in place of the model test the plan names: a stand-in for
    `FleetBackend` has no deadline). Break: the call under `answerWithin` again. Red: `Disconnected:
    org.fuin.porelo.Tasks1.AgentSignInStart was not answered within 0 seconds`.
  - `test/ui/sign_in_starting_test.dart` *a start that is out shows the mark, the time so far as it moves, and where
    to look after two minutes*. Break 1: the ticker never started. Red: `Found 0 widgets with text "1 min 5 s so
    far."`. Break 2: the mark replaced by an empty box. Red: `Found 0 widgets with type "CircularProgressIndicator"`.
    Break 3: the hint after four minutes. Red: `Found 0 widgets with text "If this does not move, gorge's log says`.
- Not checked: a real first sign-in against a machine that builds its login image; `test/ui` and `test/features`
  whole (only the files named in the hand-over ran).

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green.

## To be checked

- With Agent Core, whether `AgentSignInStart` can name its step (image build, container start) or stream it, so the
  panel says the machine's own step instead of the likely one; until then the sentence names both.
