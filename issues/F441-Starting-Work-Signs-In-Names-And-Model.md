# F441 — Starting Work Signs In, Names The Task And Its Model

```json
{
  "$schema": "issue-1.json",
  "id": "F441",
  "title": "Starting Work Signs In, Names The Task And Its Model",
  "state": "Review",
  "size": "L",
  "priority": "Medium",
  "rank": 76,
  "blockedBy": [],
  "covers": "Work starts without a host shell: the agent's sign-in asked in the window, tasks named as named, the model shown and changeable."
}
```

**Why this size.** the sign-in and batch, the names and the model, as *Size* below breaks it down.

**What must be true.** Work starts in the window without a host shell: a missing sign-in of the task's agent is asked
for in the window and waited for, a task is named as the person named it, and the model the task runs is shown and can be changed before it starts.

## Why

The third move (2026-11-08), findings 7, 10 and 11, decided by the operator that evening. Their machine side (whether
an agent is signed in, one sign-in at a time per machine and agent, task and room names, the default model per
provider in a project's provider settings) is the backend's; the window builds its part against what the backend
offers and says what it waits for.

## Acceptance

- **The sign-in** (finding 7): starting work asks the machine whether the task's agent is signed in there; if not, the
  window shows "Sign in to <agent>" with the agent's own link and waits, then starts. A start of several tasks at once
  gathers the distinct machine and agent pairs first, asks each machine once, signs in the missing ones one after
  another, and only then starts all; a sign-in already running for that machine and agent is waited on, not opened a
  second time.
- **Names** (finding 10): a task is shown by the name given at its start, or short by its repository (`pi`); the
  container's name only in its details.
- **The model** (finding 11): *New work* shows the model the task will run, with the default from the project or the
  repository, and lets it be changed; the task's row and its terminal's header name it ("Claude Code · Opus 5.5 via
  anthropic"); a start of several tasks takes each repository's default without asking.

**Blocked by** the backend's sign-in state and default model (as the room settles them); the window's parts that do
not need them are built first.

## Size

L: M the sign-in and batch, S the names, S the model. Built in that order reversed: names and model first
(not blocked), then the sign-in.

## How it stands

Built first against a stand-in of the wire agreed in the channel, then adapted to the wire as the backend built it
(its sign-in and model methods, and the task's model and name fields, in `Tasks1`). Not served by a released Porelo
yet, so `doc/Contract-Gaps.md` lists them until it is. What changed against the stand-in: the login is no task (no
`kind`, nothing in `List`, `Watch` or `Screen`, no *End the sign-in*); `AgentSignIns` takes no parameter; the
sign-in's terminal runs the `attach` the machine names on that machine; the wait answers once; the default model
comes from `ProviderModels`, not from the project's fields; `named` is a string and `display` what a client shows,
not the room's name.

## Plan

The forge token handed over when the machine asks is [F443](README.md#f443).

### 1. Client and the older daemon

Files: `lib/src/client/porelo_client.dart`, `lib/src/client/models.dart`, `lib/src/app/fleet_backend.dart`,
`lib/src/mock/mock_daemon.dart` (its open connections, for a test), `test/features/support/world.dart`
(`FakeBackend`).

- `agentSignIns()` calls `AgentSignIns` with no parameter and reads `signIns` field by field into
  `AgentSignIn(agent, state, running?)`. `state` stays a string: `VAULT_LOCKED`, `CANNOT_SAY` and an unknown one are
  shown as they come and **never count as signed in**. `running` names the container of a sign-in that runs, `""`
  while one is being prepared.
- `agentSignInStart(agent, force?, remote?)` is a single call answering `(container, started, attach)`; `force` and
  `remote` are sent only when given. `SignInRefused(agent, reason, detail)` is its own error.
- `agentSignInWait(agent)` is one call answering `(stored, reason)`, **under its own deadline of 31 minutes** (the
  machine answers within 30) **and on a connection of its own**, closed when the subscription is canceled. Every
  other call of the machine opens its own connection, as before, so a wait holds none of theirs.
- `providerModels(project, repository?)` reads `models` into `ProviderModel(provider, model, label, from)`; an entry
  with `model` `""` and `from` `agent` is the agent's own default.
- `Task.model`, `modelLabel`, `modelFrom`, `display`, `short`, `named` are **nullable**: absent (an older daemon) is
  null, so "not reported" never reads as "the agent's own default" (`model: ""`). **No model label is made here.**
- **An older daemon**: `MethodNotFound` on any of the four becomes `FeatureNotSupported` for that call alone, and the
  start goes the way it went before (`CanStart`'s `CREDENTIAL_MISSING`/`CREDENTIAL_UNUSABLE` and the agent's own
  login in a terminal on the machine).

### 2. The sign-in before a start

The sign-in is the machine's own login (as `porelo vault login <agent>` runs it), in a container of its own that
puts the provider's token into the vault; one per machine and agent. The window starts it, or has the machine answer
the one already running, and runs the `attach` the machine names **on that machine** in a terminal, as any command
the machine names: here for this computer's own daemon, over ssh in the login shell for one reached that way, and
nowhere for a socket somebody else forwards (*Sign in* is then not offered, with its reason). The person follows the
link and pastes the code **there**. The window has no paste field and sends no code.

Files: `lib/src/app/agent_sign_in.dart` (`SigningIn`, shared by the form, the batch and a failed start),
`lib/src/ui/sign_in_panel.dart`, `lib/src/app/start_work.dart`, `lib/src/app/commands.dart` (*Sign in*, *Use the
sign-in found on the machine*, *Sign in anyway, beside the sign-in found*), `lib/src/ui/shell.dart` (the machine,
`remote`, the terminal, and leaving the waits of a machine forgotten).

- **Nothing starts by itself.** Start is enabled only once the agent reads `SIGNED_IN` **and** `CanStart`, asked
  again after every stored sign-in, holds nothing back.
- **`remote: true`** for any machine this window reaches from another one, so the machine refuses a sign-in whose
  reply would come back to itself (`LOOPBACK_OVER_SSH`).
- A sign-in that runs (listed with `running`, or `started` false) is waited on; *Sign in* opens its terminal again
  without a second `AgentSignInStart` while it is waited on.
- `SignInRefused` is said with its `detail` verbatim. `ALREADY_SIGNED_IN`: *Use the sign-in found on the machine*
  (`ImportCredential`, then `AgentSignIns` asked again) first, and *Sign in anyway, beside the sign-in found*
  (`force: true`) as the second decision; *Sign in* is not offered then.
- The wait's `stored: true` reads signed in; any other end holds the start, its reason said (`TIMED_OUT`,
  `NOTHING_TO_COLLECT`, an unknown one as it comes), and *Sign in* is offered again.
- **Leaving it** (Escape, the barrier, *Not now*, the form opened again, the wizard closed, a failed start's view left,
  the machine forgotten) drops the wait and closes its connection; the sign-in goes on on the machine, which is said.
  The contract has no way to end a sign-in from the window.
- **The machine** is the one the form was opened on, for every step, as before.

### 3. The batch

*Start an agent for each repository* asks `AgentSignIns()` once, signs the missing agents in one after another, each
on its press, with the same sign-in, and sends no `Start` until every chosen row's agent reads `SIGNED_IN` and
`CanStart` holds none back. It sends **no `model`**. Older daemon: as before.

### 4. Names

A task is shown by its caption (`label`) where somebody set one, else by `display`, else by `name` as before; every
call keeps taking `name`. The container `name` is shown in its details only where the heading is another.

### 5. The model

*New work* asks `ProviderModels` of the form's machine once the project (and repository) are known, and fills the
model with the entry whose provider is the one `CanStart` names, never another provider's; `""` from `agent` reads
as the agent's own default. Not served or failed: empty, and the machine takes the provider's default. A model typed
stays tied to its agent and provider; *Continue*, *Restart* and *Recreate* keep the task's own. The row and the
terminal's header read "<agent> · <modelLabel, else the id> via <provider>", with where it came from beside it.

### Tests (each guards a harm)

Client tests against `MockDaemon`; frame tests as Gherkin features under `test/features` against `FakeBackend`.

- Client: a shut vault, `CANNOT_SAY` or an unknown state never reads signed in; `force` and `remote` only where
  given; `SignInRefused` with its reason and detail; `MethodNotFound` on each to `FeatureNotSupported`; the wait not
  cut by the single call's deadline; the wait on a connection of its own, other calls answered meanwhile, and its
  connection closed once left; the models per provider.
- Frame: no `Start` while not signed in (each state, a refusal, a lost connection, each end of the wait), while
  `CanStart` holds, or by itself after signed in; never a second sign-in beside one that runs; leaving does not end
  the sign-in and drops the wait, the machine forgotten too; the wrong machine; `attach` over ssh on a machine
  reached so, and `remote` sent; `ALREADY_SIGNED_IN` forces nothing without the second press; the batch's order;
  an older daemon as before; a model of another provider never taken.

### What is still open

- Whether closing the terminal of a sign-in leaves the login running depends on what the machine's `attach` does
  with the terminal's hang-up; the window only closes its terminal and never asks for an end.
- `Start` names no refusal for a sign-in gone missing meanwhile, so after a failed start the window asks
  `AgentSignIns` of that machine and offers *Sign in* on the operation where the agent is not signed in.
- `CANNOT_SAY` holds the start like any state but `SIGNED_IN`, though the machine says which credential a start needs
  is then the start's choice.
