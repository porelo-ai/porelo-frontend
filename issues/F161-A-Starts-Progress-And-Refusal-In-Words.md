# F161 — A Start's Progress And Refusal In Words

**Status:** Implementing; blocked by `porelo` [B268](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b268), which reports a task's start step by step.
**Size:** M - the client's `Start`, the backend's stream, the operation's view, the mock and their tests.

**What must be true.** While *Start it* runs, the interface says in plain words which step is
running and what it waits on, and ends with the cause when something it waits on (such as the
room's homeserver) has failed. When a start is refused for the repository's own `porelo.yml`, the
interface says that the file belongs to the repository, who changes it, and that nothing was
started.

The interface only shows these texts. Each comes from where its step is defined, never written a
second time here: a task's start from porelo's daemon, a host's steps from the collection through
`porelo-host`'s JSON step lines. The interface writes texts only for its own actions.

## Why

While *Start it* runs, the person sees only a trailing line such as `snippet…`, with no plain-words
step and nothing saying it waits on a homeserver that has already failed. When a start is refused
for `porelo.yml` (such as `'image.env.LANG' is set by Porelo and cannot be set here`), the
interface shows only `porelo`'s words without saying whose file it is or whether anything started.

## Plan

- **Today**, read in the code: `PoreloClient.start` (`porelo_client.dart`) streams `StartProgress`
  with a `line`, and the final reply's exit code and `StartAction`. `FleetBackend.startTask`
  reduces it to a `Stream<String>` of lines, which `Operations.run` keeps and the operation's view
  shows. A non-zero end becomes `OperationFailed`, whose words for 69 the interface writes itself.
  Nothing has a step.
- **The contract, as agreed with porelo's owner:** `StartStep` (`step`, `state`, `text`,
  `waitingOn`, `cause`), streamed as its own reply only when `Start` is sent `steps: true`, a
  reply carrying `line` or `step`, never both; `Task.phase` names the step a task is in, and its
  wait. The client sends `steps: true` only when the served interface description declares it on
  `Start`, so a daemon from before it gets today's call. Unknown `step` and `state` values are
  shown by their text.
- **The stream:** `startTask` yields lines and steps both. The operation keeps each step's last
  state by its `step` name and shows them as a list: the `text`, what it waits on, and for a
  `FAILED` step its `cause`, verbatim; the lines stay under the steps, as today's details.
- **The interface's own words:** where steps came, the 69 sentence is not written, since the
  failed step says what was refused. Where none came, an older daemon, it stays as it is.
- **A refusal of the repository's `porelo.yml`**, read in porelo's code by its owner: an ordinary
  final reply, exit code 64, its words as lines; with steps, a `FAILED` step, `CHECKS` before the
  gate's fetch or `WORKSPACE` after it, whose `cause` is the refusal's first line. porelo's own
  sentence says whose file it is, who changes it, and that nothing was created, so the interface
  shows it as it comes and adds nothing.
- **The mock** serves steps for a start when asked with `steps: true`, driven by the test, and a
  start whose `CONVERSATION` step waits on the room's homeserver and then fails with its cause.
- **Tests, their harm, red first:** a start whose dependency failed ends showing that step's
  cause, never left reading as still waiting (today only the last line shows until it times out);
  `steps` is not sent to a daemon whose description lacks it (a start refused or misread on an
  older daemon); the 69 sentence stays when no step came.
- **Not here:** a host's steps are [F154](README.md#f154)'s, through `porelo-host`'s lines.

## Acceptance

- During a start, the view shows the current step and what it waits on in plain words, stops with
  the cause when a required service has failed, and on a `porelo.yml` refusal states that the file
  belongs to the repository, who changes it, and that nothing was started.
- Seen to fail first: a start whose homeserver fails today shows only the last output line until
  it times out; the test that holds the named cause goes red on it.
