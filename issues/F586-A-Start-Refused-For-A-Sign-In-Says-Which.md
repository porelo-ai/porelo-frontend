# F586 — A Start Refused For A Sign-In Says Which

```json
{
  "$schema": "issue-1.json",
  "id": "F586",
  "title": "A Start Refused For A Sign-In Says Which",
  "state": "Backlog",
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
