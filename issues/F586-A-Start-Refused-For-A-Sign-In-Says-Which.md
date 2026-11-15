# F586 — A Start Refused For A Sign-In Says Which

```json
{
  "$schema": "issue-1.json",
  "id": "F586",
  "title": "A Start Refused For A Sign-In Says Which",
  "state": "Review",
  "size": "M",
  "priority": "High",
  "rank": 14,
  "blockedBy": [],
  "covers": "A start the machine refuses with SignInNeeded says in words which agent on which machine needs a sign-in, on the Planning board, a start's operation and every other start path, and leads to where that sign-in is made, instead of the raw error org.fuin.porelo.Tasks1.SignInNeeded {agent: claude}."
}
```

**Why this size.** One set of words for a refused start, used by two paths that print the error today, and a way
from the Planning board, which shows only a line, to the sign-in the window already has (`SigningIn`,
`SignInPanel`); tests on both paths.

**What must be true.** A person whose start is refused because an agent is not signed in on the machine reads which
agent and which machine, and is one press from signing it in there; never the wire's error name.

## Found

The operator's live test on a host (snapshot 0.5.1~snapshot.552): *Discuss an idea* on the Planning board showed
`org.fuin.porelo.Tasks1.SignInNeeded {agent: claude}` in red, with *Planning changes saved.* below. Porelo's `Start`
refuses with `SignInNeeded(agent, running: ?string)` when the agent's model credential is missing; no task, hooks or
helpers were made (`15-task.varlink`).

## Plan

- **Today**, read in the code:
  - Planning: `WindowTaskStarts`' start (`lib/src/ui/planning_embedding.dart`, the `on VarlinkException` branch
    near line 227) passes `error.toString()` to `_sayRefused` and into the `PlanningRefusal` the board shows, so any
    wire error reads raw there, `SignInNeeded` included. Nothing offers a sign-in.
  - A start from the start dialog (*Work*, a project's *Tasks*): `Operations.run`'s `onError`
    (`lib/src/app/operations.dart` ~385) ends the operation with `'$error'`, the same raw text, as its last line; the
    shell's `_offerASignInIfItFails` (`lib/src/ui/shell.dart`) then asks the machine and shows `SignInPanel` on the
    operation, but only where the press asked for it (`pressed.signsIn`), and the line above it stays raw.
  - No code in `lib` names `SignInNeeded`.
- **Steps.**
  - One function for a refused start's words (beside `reasonFirst`, or in `lib/src/app/start_work.dart`):
    `SignInNeeded` says "<agent label> is not signed in on <machine>; sign it in there, then start again." and, with
    `running`, that a sign-in already runs there; `FirstStartRefused` and the other `Start` errors of
    `15-task.varlink` in their own words; an unknown error by its detail, never by its type name alone.
  - The operation's failure and the Planning board's refusal both use it.
  - Planning: on `SignInNeeded` the window adds a *Needs you* row *Sign in to <agent> on <machine>* that opens the
    machine's sign-in (`SigningIn` with `SignInPanel`, as after a failed start), and drops it once the machine says
    the agent is signed in. On a remote host, until [F584](README.md#f584)'s relay stands, it says that a `LOOPBACK`
    login is made at the host or carried by *Import from this computer…*; with [F584](README.md#f584) it starts the
    host's own sign-in.
  - Every start path checked for raw wire errors: the board, the start dialog's operation, *Discuss an idea* from a
    project, a work tile's restart; each listed in *Built*.
- **Red first** (harm: a person reads a type name and does not know that a sign-in is missing, or where): a widget
  test of the Planning start refused with `SignInNeeded` saying the agent and machine and showing the *Needs you*
  row; an operation test of the same refusal's last line; a unit test of the words for each `Start` error, an
  unknown one included; each seen red.

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green; a feature scenario in
  `test/features/planning_discussion.feature` beside the refused start's.

## Built

- `lib/src/app/start_refusals.dart` (new): `SignInNeeded` (agent, running, the label from the machine's `Agents`
  answer), `startRefusalSaid` (the one mapping of Start's named errors to typed refusals, now also used by
  `startRefusalsSaid` in `fleet_backend.dart`), `startRefusalWords(error, machine:)`, the one set of words: SignInNeeded
  ("<agent> is not signed in on <machine>, so nothing was started. Sign it in there, then start again."; with
  `running`, that a sign-in already runs there), VaultLocked, FirstStartRefused, UnknownHostKey, BranchTaken,
  ContainerNameTaken, AlreadyStarting, MadeWithAnother, NoSuchTask, MethodNotFound, the typed EarlierWorkWaits,
  UpstreamUnreadable and NoSuchDestination as before, an unknown error by its detail, message or reason, and without
  any as "<machine> refused (<Name>: key value, …)", never the wire's name alone. The refusals only a task's MCP socket
  answers (ChildLimitReached and the rest) are not worded: the window never starts through that socket, and they fall
  to the unknown branch. `SignInsNeeded` keeps one `SigningIn` per machine and agent and drops it once its
  `signedIn` says so, or once its machine is no longer watched.
- `lib/src/app/operations.dart`: an operation's failure ends with `startRefusalWords(error, machine:)` instead of
  `'$error'`; the words for VaultLocked and NoSuchTask are neutral, as every operation's error passes through it.
- `lib/src/app/start_work.dart`: the press labels a SignInNeeded with the form's agent label.
- `lib/src/ui/planning_embedding.dart`: `WindowTaskStarts` takes any refused start through the same words (the
  label asked of `agentsOn`, the agent's name where it does not answer); the `PlanningRefusal` carries them as its
  `detail`, which the board reads first, and on SignInNeeded adds "Needs you offers its sign-in." and calls the new
  `onSignInNeeded`.
- `lib/src/ui/shell.dart`: `onSignInNeeded` puts the machine's sign-in (`_signInOn(SigningIn())`, asked as after a
  failed start) into `SignInsNeeded`; dropped with forgotten machines and on dispose.
- `lib/src/app/attention.dart`, `lib/src/ui/attention_view.dart`, `lib/src/app/commands.dart`: a new row kind
  `signIn` (id `sign in <machine>/<agent>`), titled *Sign in to <agent> on <machine>*, its primary command
  *Sign in on <machine>* (`signIn.needed`) starting the machine's sign-in and its terminal; opened, it shows the
  `SignInPanel` and, where the machine refused a `LOOPBACK_OVER_SSH` sign-in, that it is made at the machine itself or
  carried with "Import from this computer…" under its Agents & providers. Resolved, it reads *Signed in* under
  *Recently resolved*.
- `lib/src/app/fleet_model.dart`: a work tile's restart (`startAgain`) refused by Start is said in the same words; a
  typed refusal (EarlierWorkWaits, UpstreamUnreadable, NoSuchDestination, now SignInNeeded) escaped it uncaught before.
- `lib/src/app/start_agents.dart`: a refused row of *Start agents* takes the same words, labelled.
- Start paths checked: the Planning board's ordered start and *Discuss an idea* (from the board and from a project,
  both `WindowTaskStarts`); the start dialog (*Work*, a project's *Tasks*), *Recreate* and *Show what … would open*,
  all `Operations.run`; a work tile's *Start it again* (`FleetModel.startAgain`); *Start agents*. The machine's own
  printed refusals (exit codes with lines) keep their path through `reasonFirst` and `startWords`.
- Decided: the *Needs you* row comes only from a Planning start; the start dialog keeps its `SignInPanel` on the
  operation. A row is dropped only by its own sign-in's answer (or its machine forgotten), not by a sign-in made
  elsewhere; the next refused start of the same agent adds no second row.

Guards, each seen red first (break from a copy, restored, `cmp` equal, `git diff --stat` unchanged):

- `test/app/start_refusals_test.dart`
  - missing sign-in names agent and machine / every other refusal in its own words — break: `startRefusalWords`
    skips `startRefusalSaid`; red: "Expected: contains 'claude is not signed in on build-host' Actual: 'build-host
    refused (SignInNeeded: agent claude).'" and "Expected: not contains 'EarlierWorkWaits'".
  - the label — break: `who` ignores the label; red: "Expected: a string starting with 'Claude Code is not signed
    in on build-host' Actual: 'claude is not signed in …'".
  - through Start's stream — break: the mapping's SignInNeeded case renamed; red: "emitted !
    org.fuin.porelo.Tasks1.SignInNeeded {agent: claude}".
  - unknown refusal — breaks: detail branch and no-detail branch to `'$said'`; red: "Actual:
    'org.fuin.porelo.Tasks1.SomethingNew {detail: The moon is in the way}'" and "Expected: contains 'build-host
    refused' Actual: 'org.fuin.porelo.Tasks1.SomethingNew {which: moon}'".
  - an operation refused for a sign-in — break: `onError` back to `'$error'`; red: "Expected: a string starting
    with 'claude is not signed in on build-host' Actual: 'claude is not signed in on the machine, …'".
- `test/app/fleet_model_test.dart`, a restart refused for a missing sign-in — break: the catch narrowed to
  `UnsupportedError`; red: the refusal escaped `FleetModel.startAgain` uncaught.
- `test/features/planning_discussion.feature`, *A discussion Start refused for a sign-in names the agent and
  machine, and Needs you signs it in* — breaks: the words back to `error.toString()` (red: "Expected: contains
  'Another Agent is not signed in on this machine' Actual: 'org.fuin.porelo.Tasks1.SignInNeeded {agent:
  other-agent} …'"); `onSignInNeeded` not called (red: "Found 0 widgets with text \"Sign in to Another Agent on this
  machine\""); `SignInsNeeded` never drops (red: "Expected: no matching candidates Actual: Found 1 widget with key
  'needs-you-sign-in'").
- `test/ui/window_task_starts_test.dart`: the VaultLocked expectation reads the window's words now.

Not checked: a real host's SignInNeeded was not replayed (no VM, no window); `test/ui` and `test/features` were not
run whole.

### After the reading

Another model read the change. Fixed, each with a guard seen red:

- An unknown refusal with no detail, message or reason printed every parameter's value. It now names the error and
  the parameter keys only ("<machine> refused (Name: key, key)"). Break: keys back to "key value"; red: "Expected:
  'build-host refused (SomethingNew: which, token).' Actual: '… (SomethingNew: which moon, token hunter2-secret).'"
- `SignInsNeeded` had no tests. A second refusal for the same machine and agent adds no second row (break: the
  check for a kept one removed; red: "Expected: <2> Actual: <3>"). `keepOnly` drops the row of a machine no longer
  watched (break: it keeps every row; red: "Expected: ['laptop'] Actual: ['build-host', 'laptop']").
- An operation that is no start (a stop or a removal failing with NoSuchTask, VaultLocked or an unknown error) is
  said in words that fit any operation. Break: VaultLocked worded as a start's; red: "Expected: not contains 'start'".
- `FleetModel.startAgain` caught every exception. It now catches only Start's refusals (`isStartRefusal`: a
  `VarlinkException`, `SignInNeeded`, `NoSuchDestination`, `EarlierWorkWaits`, `UpstreamUnreadable`, `StartRefused`);
  a lost connection, an older machine, a timeout or a socket's fault goes on as before. Break: the rethrow removed;
  red: "Expected: throws <Instance of 'TimeoutException'> … emitted <null>".
- The board said "Needs you offers its sign-in." whenever an offer was wired. `onSignInNeeded` and
  `SignInsNeeded.need` now answer whether the row stands, and the board says it only then. Break: said on every
  SignInNeeded; red: "Expected: not contains 'Needs you' Actual: '… Needs you offers its sign-in.'"
  (`test/ui/window_task_starts_test.dart`).

Left as it is: the agent's label in a restart's words, and in an operation's other than the start form's. Neither
`FleetModel` nor `Operations` holds the machine's agents list, so these name the agent by the name the machine sent.
The start form, *Start agents* and the Planning start use the label. The other points left open are under *To be
checked*.

## To be checked

- A *Needs you* sign-in row resolves only on its own sign-in's `signedIn` answer: one made elsewhere (the start form,
  a terminal at the machine) leaves it until it is pressed or its machine is forgotten.
- The row's key is the machine's name, so a machine renamed leaves its row until the machine is forgotten.
- The row's `ask()` runs on the backend of the start that was refused, which may be stale after a reconnect.
- The row's LOOPBACK note (made at the machine or carried with "Import from this computer…") has no test.
