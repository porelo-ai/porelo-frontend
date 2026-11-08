# F441 — Starting Work Signs In, Names The Task And Its Model

**Status:** Review.

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

## Plan

Read once before building; this is the plan after that reading. Built against the daemon wire agreed in the channel
for these parts (Tasks1), not yet served by any daemon, so against stand-ins. Order: names and model first (not
blocked), then the sign-in. The forge token handed over when the machine asks is [F443](README.md#f443).

### 1. Client and the older daemon

Files: `lib/src/client/porelo_client.dart`, `lib/src/client/models.dart`, `lib/src/app/fleet_backend.dart` (the
`FleetBackend` interface and its machine implementation), `test/features/support/world.dart` (`FakeBackend`),
`doc/Contract-Gaps.md` ("Not on the wire yet": the three methods and the new fields, until served).

- `agentSignIns(agents)` calls `AgentSignIns` with `agents` only when named; reads `signIns` field by field into
  `AgentSignIn(agent, provider, state, since?, signingInSince?, loginTask?)`. `state` stays a string: an unknown one
  is shown as it comes and **never counts as signed in**; a stored API key reads `SIGNED_IN`.
- `agentSignInStart(agent)` is a single call answering `(task, started)`: the login task it started, or the one that
  runs with `started` false. No stream; no code is sent.
- `agentSignInWait(agent)` streams `AgentSignInWait` into its `state` (and `detail` if one comes); the last reply is
  `SIGNED_IN` or `NOT_SIGNED_IN`; with nothing running it answers once with the current state and ends. It ends only
  on its final reply; anything else is an error.
- Errors become typed exceptions beside `FeatureNotSupported`: `CannotSignIn(agent, reason)`, `NoSuchAgent(agent)`,
  `VaultShut`; any other error stays a `VarlinkException`.
- `Task.kind` is nullable (`LOGIN` for a login task, absent from an older daemon); a login task is listed like any
  task.
- `Task.model`, `Task.modelLabel`, `Task.display`, `Task.short` are **nullable**: absent (an older daemon) is null,
  so "not reported" never reads as "the agent's own default" (`model: ""`). `Project.defaultModels` and
  `Repository.defaultModels` are `List<ProviderModel(provider, model, label, from)>`, empty when absent; `from` kept
  as a string. **No model label is made here**: `label` and `modelLabel` are shown as they come, else the id.
- `Start`'s `model` is already a parameter of `startTask`; it stays sent only when named.
- **An older daemon**: `MethodNotFound` on any of the three becomes `FeatureNotSupported` for that call alone, and the
  start goes the way it goes today (`CanStart`'s `CREDENTIAL_MISSING`/`CREDENTIAL_UNUSABLE` and the agent's own login
  in a terminal on the machine). A reply without the new fields reads without a crash.

### 2. The sign-in before a start

The sign-in is Porelo's own login task (today `porelo vault login <agent>`), which puts the provider's token into the
vault; one per machine and agent. The window starts it, or finds the one already running, and opens its terminal as
any task's: the person follows the link and pastes a code **there**. The window has no paste field, sends no code,
and opens no sign-in link of its own, so this repository's rule that the interface takes no secret into a form of its
own, and `doc/design.md`'s line that provider sign-ins keep their own terminal paths, stay as they are.

Files: `lib/src/app/agent_sign_in.dart` (new: `SigningIn`, one sign-in of one agent on one machine, a
`ChangeNotifier`, shared by the form and the batch), `lib/src/ui/sign_in_panel.dart` (its panel),
`lib/src/ui/login_task_terminal.dart` (the login task's terminal over the form, opened through `Sessions` beside the
one session of *Running*), `lib/src/app/start_work.dart` (owns it), `lib/src/app/commands.dart` (*Sign in* and *End the
sign-in* as Commands, each with the reason it cannot run now), `lib/src/ui/start_work_view.dart` (the panel),
`lib/src/ui/shell.dart` (wiring: the login task's terminal opened through `Sessions`, as any task's).

**One dialog.** The start dialog stays open while the person signs in. What it waits on is owned by `StartWork`, not
by the dialog's state, so a rebuild or a back step never drops it. Nothing starts by itself: Start is enabled only
once the agent reads `SIGNED_IN` **and** `CanStart`, asked again after every `SIGNED_IN`, holds nothing back.

**`AgentSignIns` and `CanStart` together.** On a daemon with the methods, this panel replaces today's "Sign in first"
for a missing credential of the agent; both answers must clear before Start. On an older one, today's path alone.

**The machine.** The form remembers the machine it was opened on, and every step around the start takes that one,
never the current one read at the click: the sign-in calls, the login task's terminal, `CanStart`,
`askBeforeTheFirstTask`, the `Start` in `_run`, the operation's machine, `UnattendedRun`, `_workInItOnceUp` and the
terminal it opens, and every sentence said about it.

When the agent to run is known (picked, or chosen by the machine), the form asks `AgentSignIns([agent])`. Start
stays disabled while it is out. What the person sees, by state:

- `SIGNED_IN`: nothing more.
- `NOT_SIGNED_IN`: "Sign in to <agent label>" and *Sign in*. It runs `AgentSignInStart(agent)`, which starts the
  login task or answers the one that runs (`started` false), and opens that task's terminal on the form's machine. The panel says "Follow the link in the
  terminal of <login task> on <machine> and sign in there; this waits for it", and waits (`AgentSignInWait`).
- `SIGNING_IN` (with its `loginTask`), or `started` false: the same, for the login task already running: "Another
  sign-in to <agent> on <machine> is running; waiting for it", `AgentSignInWait`, and *Sign in* opens that task's
  terminal; **no second login task is started**.
- Wait's `SIGNED_IN`: "Signed in to <agent> on <machine>"; `CanStart` is asked again; Start is enabled once both
  clear. `NOT_SIGNED_IN` (with its detail where one comes): *Sign in* again.
- `VAULT_SHUT` (from the list or from Wait) or `VaultShut`: "The vault on <machine> is shut, so nothing can be signed
  in or started", and the existing *Open the vault* (this device); then asked again.
- `CANNOT_SIGN_IN` or `CannotSignIn`: its reason verbatim.
- `NoSuchAgent`: "<agent> is not installed on <machine>".
- An unknown state, a refusal, a lost connection, or a wait that ends before `SIGNED_IN`: said with its words, **the
  start stays held**, and *Sign in* is offered again. Not read is never fine.

**Leaving it.** The login task is a task of its own: closing the dialog (Escape, the barrier, *Not now*) drops only
the wait and **does not end it**; it stays in the list, and the window says "The sign-in to <agent> goes on in its
own task on <machine>". *End the sign-in* in the panel ends it on purpose by stopping the login task as any task is
stopped, and keeps the dialog; its end goes into its last state like a task's. *Sign in* is disabled while a start is
out.

**A link shown in the window.** None is planned: the link is in the login task's terminal. Should the window still
show one, it opens only on a press, its host named beside it, and only when it parses as `https` with a host, built on
`Granting`'s address check narrowed to `https`.

**A race.** A `Start` refused because the sign-in went missing after all (another window, an expired login) is shown
as that operation's failure with *Sign in* offered there; it is **never retried as a bare Start**.

Every await is followed by a check that the same form on the same machine is still open; an answer for an earlier
opening lands nowhere.

### 3. The batch

Files: `lib/src/app/start_agents.dart`, `lib/src/ui/start_agents_view.dart`, `lib/src/ui/shell.dart`.

The batch exists: *Start an agent for each repository* (`StartAgents`), on one machine, holding every start until
the machine says each can. On a daemon with the methods its sign-in step becomes:

- After the repositories are chosen it gathers the distinct agents of the rows to start, keyed by agent on its one
  machine, and asks `AgentSignIns(agents)` once.
- The missing ones are signed in one after another with the same sign-in, each in its login task's terminal; a
  running one is waited on, never opened twice.
- **No `Start` is sent until every chosen row's agent reads `SIGNED_IN`** and `CanStart` holds none back. If a
  sign-in fails or is ended, the batch stops there and says which agent; nothing is started.
- Closing the wizard stops the waiting and says the login task goes on; *End the sign-in* ends it.
- The batch sends **no `model`**: each start takes its repository's default on the machine.
- Older daemon: today's step (`CanStart` per row, the terminal login).

### 4. Names

Files: a `Task.shown` in `lib/src/client/models.dart`, and every place a task is named to a person, in `lib/src/ui`
and `lib/src/app` alike: among them `lib/src/ui/panes.dart`, `lib/src/ui/running_view.dart`, `lib/src/ui/shell.dart`,
`lib/src/ui/attention_view.dart` (two places), `lib/src/ui/machine_tree.dart`, and `start_work.dart`'s "Continue
<name>"; found by reading every use of `Task.name`, `Task.task` and `Task.label` in both.

- A task is shown by its caption (`label`) where somebody set one, else by the name given at its start, else by
  `short`. Whether `short` is the given name where one was given is asked of Porelo; until answered, the given name
  comes first.
- `display` where the room's name of the task is meant (the mailbox and room card).
- The container `name` only in its details; every call keeps taking `name`, the identity.

### 5. The model

Files: `lib/src/app/start_work.dart`, `lib/src/ui/start_work_view.dart`, the task row and the terminal's header
(`lib/src/ui/running_view.dart`, `lib/src/ui/machine_tree.dart`).

- *New work* shows "Model", a text field prefilled with the default whose provider equals the provider the machine
  names for the start (`CanStart`'s `provider`), from `Repository.defaultModels`, else the project's; its label
  beside it, with "from the repository" or "from the project". No provider known, or none named for it: empty,
  "The agent's own default".
- When the agent changes and with it the provider, a default is replaced by the new provider's; a typed model is
  cleared and "<model> was for <provider>; the model is <new default or the agent's own default> now" is said.
- What the field holds is sent as `Start`'s `model` when non-empty; empty is not sent.
- *Continue* and *Restart* prefill the task's own `Task.model`.
- The row and the terminal's header read "<agent label> · <modelLabel> via <provider>" when `Task.model` is
  non-empty, `modelLabel` as it comes (else the id); `""` reads "<agent label> · its own default model"; null
  (older daemon) shows as today.

### Tests (each guards a harm)

Client tests against `MockDaemon`; frame tests as Gherkin features under `test/features` against `FakeBackend`.

- **An older daemon**: without the methods the start goes on as today (`CanStart`, the terminal login); a `Task`
  and a `Project` without the new fields read without a crash, as null and empty; `Start` carries no `model` unless
  one was typed.
- Client: each method's parameters and replies; each error to its type; `MethodNotFound` on each to
  `FeatureNotSupported`; a login task's `kind`.
- **A start without a sign-in**: with `NOT_SIGNED_IN`, `SIGNING_IN`, `VAULT_SHUT`, `CANNOT_SIGN_IN`, an unknown
  state, a refusal, a lost connection, a wait ended before `SIGNED_IN`, and Wait's `VAULT_SHUT` or unknown state,
  Start stays disabled and the stand-in sees no `Start`. After `SIGNED_IN` with `CanStart` still holding, no `Start`.
  No start happens by itself after `SIGNED_IN`.
- **A second sign-in**: with `SIGNING_IN`, and with `started` false, the stand-in sees `AgentSignInWait` and no
  further `AgentSignInStart`; two batch rows of one agent make one sign-in.
- **A race not retried**: a `Start` refused for a missing sign-in is one `Start`, never a second.
- **Leaving**: Escape, the barrier and *Not now* during a sign-in send no `Start` and do not end the login task;
  *End the sign-in* ends it, and no `Start` follows.
- **The terminal on the right task**: *Sign in* with a login task already running opens that task's terminal and
  starts none.
- **The wrong machine**: the form opened on machine A, the current machine switched to B; every sign-in call and the
  `Start` reach A's stand-in, none B's, the operation names A, and the session opened afterwards is on A.
- **The batch**: one `AgentSignIns` per opening; the second agent's sign-in starts only after the first's
  `SIGNED_IN`; no `Start` before all are signed in; a failed or ended sign-in starts nothing; closing the wizard
  starts nothing and leaves the login task; no `Start` of the batch carries `model`.
- **The model kept**: *Restart* and *Continue* send the task's own model; a typed model is not sent for another
  provider after the agent changed.

### What of the wire is still guessed

- Where "the sign-in was left" comes on Wait: the window shows a `detail` if one comes and otherwise says only that
  the sign-in ended without signing in.
- Which refusal `Start` gives when the sign-in went missing in a race: none is named, so after a failed start the
  window asks `AgentSignIns` of that machine and offers *Sign in* on the operation where the agent is not signed in.
