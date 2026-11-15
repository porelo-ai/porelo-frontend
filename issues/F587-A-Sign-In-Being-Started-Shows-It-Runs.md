# F587 — A Sign-In Being Started Shows It Runs

```json
{
  "$schema": "issue-1.json",
  "id": "F587",
  "title": "A Sign-In Being Started Shows It Runs",
  "state": "Implementing",
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

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green.

## To be checked

- With Agent Core, whether `AgentSignInStart` can name its step (image build, container start) or stream it, so the
  panel says the machine's own step instead of the likely one; until then the sentence names both.
