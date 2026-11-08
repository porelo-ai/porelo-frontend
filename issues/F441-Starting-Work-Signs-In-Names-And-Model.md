# F441 — Starting Work Signs In, Names The Task And Its Model

**Status:** Implementing.

**What must be true.** Work starts in the window without a host shell: a missing sign-in of the task's agent is asked
for in the window and waited for, the forge token is handed over when the machine asks, a task is named as the person
named it, and the model the task runs is shown and can be changed before it starts.

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

L: M the sign-in and batch, S the names, S the model.

## Plan

To be read before it is built. Built against the daemon wire Porelo named for these parts (Tasks1, new methods in
its agent interface); it may still change after Porelo's own plan reading, and what is guessed of it is listed last.

### 1. Client and the older daemon

Files: `lib/src/client/porelo_client.dart`, `lib/src/client/models.dart`, `lib/src/app/fleet_backend.dart` (the
`FleetBackend` interface and its machine implementation), `lib/src/mock/mock_daemon.dart` only where a test needs a
handler, `doc/Contract-Gaps.md` ("Not on the wire yet": the five methods and four fields, until served).

- `agentSignIns(agents)` calls `AgentSignIns` with `agents` only when named; reads `signIns` field by field into
  `AgentSignIn(agent, provider, state, since?, signingInSince?)`. `state` stays a string: an unknown one is shown as
  it comes and **never counts as signed in**.
- `agentSignInStart(agent)` streams `AgentSignInStart` through `_callMore` into `SignInStep(session, step, url?,
  code?, detail?)`; the stream ends only on the final reply (`SIGNED_IN`), anything else is an error.
- `agentSignInCode(session, code)`, `agentSignInCancel(session)` single calls; `agentSignInWait(agent)` streams
  `AgentSignInWait` into its `state`, last reply `SIGNED_IN` or `NOT_SIGNED_IN`.
- Errors become typed exceptions beside `FeatureNotSupported`: `SignInRunning(agent, session, since)`,
  `CannotSignIn(agent, reason)`, `VaultShut`, `NoSuchAgent(agent)`, `SignInFailed(agent, detail)`,
  `NoSuchSession(session)`; any other error stays a `VarlinkException`.
- `Task.model`, `Task.display`, `Task.short` are **nullable**: absent (an older daemon) is null, so "not reported"
  never reads as "the agent's own default" (`model: ""`). `Project.defaultModels` and `Repository.defaultModels` are
  `List<ProviderModel(provider, model, from)>`, empty when absent; `from` kept as a string.
- `Start`'s `model` is already a parameter of `startTask`; it stays sent only when named, so an older daemon never
  meets it unasked.
- **An older daemon**: `MethodNotFound` on any of the five becomes `FeatureNotSupported` for that call alone, as
  today. The start then goes the way it goes today: `CanStart`'s `CREDENTIAL_MISSING`/`CREDENTIAL_UNUSABLE` and the
  agent's own login in a terminal on the machine. No field absent from a reply breaks a reader.

### 2. The sign-in before a start

Files: `lib/src/app/start_work.dart` (a `SignIn` state held by `StartWork`, on the machine the form was opened on),
a new `lib/src/app/agent_sign_in.dart` (one sign-in of one agent on one machine, shared by the form and the batch),
`lib/src/ui/start_work_view.dart` (the sign-in panel), `lib/src/ui/shell.dart` (wiring: link opener, copy, the
vault's opening; the start's `_run` given the start's own backend, never `_fleet.backend` read at the click).

- When the agent to run is known (picked, or chosen by the machine), the form asks `AgentSignIns([agent])` of the
  machine it was opened on. Start stays disabled while that question is out, as it is while `CanStart` is out.
- The person sees, by state:
  - `SIGNED_IN`: nothing more; Start as today.
  - `NOT_SIGNED_IN`: "Sign in to <agent label>" with a button. It runs `AgentSignInStart(agent)`: "Starting the
    sign-in on <machine>…" for `STARTING`; for `LINK` the link (opened in the browser by the existing link opener
    once, offered again as a button, and Copy), and the code where one is given, "Enter this code on the page";
    for `WAITING_FOR_CODE` a field "Paste the code the page showed you" and Send (`AgentSignInCode`); on the final
    `SIGNED_IN` "Signed in to <agent> on <machine>" and the start goes on by itself if the person had pressed
    Start, else Start is enabled.
  - `SIGNING_IN`, or `SignInRunning` from `AgentSignInStart`: "Another sign-in to <agent> on <machine> is running;
    waiting for it", with `AgentSignInWait(agent)`; **no second `AgentSignInStart` is sent**. Its `SIGNED_IN` goes
    on as above; its `NOT_SIGNED_IN` comes back to "Sign in to <agent>".
  - `VAULT_SHUT` or `VaultShut`: "The vault on <machine> is shut, so nothing can be signed in or started" and the
    existing *Open the vault* (this device), then the question is asked again.
  - `CANNOT_SIGN_IN` or `CannotSignIn`: its reason verbatim; where the agent's own login in a terminal on the
    machine is reachable (today's path), it is offered beside it.
  - `NoSuchAgent`: "<agent> is not installed on <machine>"; `SignInFailed`: "The sign-in failed: <detail>" and the
    button again; `NoSuchSession` on a code or a cancel: "That sign-in ended on <machine>; start it again".
  - A lost connection or any other refusal: said with its words; **the start stays held** (not read is not fine).
  - An unknown state: "<agent> on <machine>: <state>", held.
- **Cancel** (in the panel, and closing the form while a session is running) sends `AgentSignInCancel(session)`
  and drops the stream; nothing starts. Back in the form keeps the session running and its panel.
- A waiting `AgentSignInWait` is only dropped on cancel, never cancels the other window's session.
- `Start` refused for a missing sign-in after all (a race with another window) shows the sign-in panel again
  rather than a bare failure.
- Every await is followed by a check that the same form on the same machine is still open; an answer for an
  earlier opening lands nowhere.
- **The code is a secret of the person's sign-in**: the pasted code goes only into `AgentSignInCode`, is cleared
  from the field once sent, and is never put into an operation's output, a `say`, a log line or an exception's
  words. The link and a device code from the daemon are shown, never logged. A link is opened only when it is
  `https`.

### 3. The batch

Files: `lib/src/app/start_agents.dart`, `lib/src/ui/start_agents_view.dart`, `lib/src/ui/shell.dart`.

The batch exists: *Start an agent for each repository* (`StartAgents`), on one machine, already holding every start
until the machine says each can. Its sign-in step changes:

- After the repositories are chosen it gathers the distinct agents of the rows to start (the batch runs on one
  machine; the pairs are keyed by machine and agent all the same, so a batch over several machines takes the same
  helper) and asks `AgentSignIns(agents)` **once per machine**.
- The missing ones are signed in one after another with the same `AgentSignIn` panel, one agent at a time; a
  running one is waited on (`AgentSignInWait`), never opened twice.
- **No `Start` is sent until every chosen row's agent reads `SIGNED_IN`**; a row whose agent cannot be signed in is
  held with its reason, and the person can leave those rows out to start the rest.
- Each row's `Start` carries that repository's default model for its provider (`Repository.defaultModels`), without
  asking; none named, `model` is not sent.
- Older daemon: the step is today's (`CanStart` per row, the terminal login).

### 4. Names

Files: `lib/src/ui/machine_tree.dart` and the other places a task is named for a person (found by reading every use
of `Task.task` and `Task.label` in `lib/src/ui`), a helper `Task.shown` in `models.dart`.

- A task is shown by its caption (`label`) where somebody set one, else by `short`, else as today (`task`).
- `display` where the room's name of the task is meant (the mailbox and room card).
- The container `name` only in its details; every call keeps taking `name` (the identity).
- Older daemon: as today.

### 5. The model

Files: `lib/src/app/start_work.dart`, `lib/src/ui/start_work_view.dart`, the task row and the terminal's header
(`lib/src/ui/running_view.dart`, `lib/src/ui/machine_tree.dart`), a small `lib/src/app/model_names.dart`.

- *New work* shows "Model", a text field prefilled with the default for the chosen provider from
  `Repository.defaultModels` (else the project's), with "from the repository" or "from the project" beside it;
  none named: empty, "The agent's own default".
- What the field holds is sent as `Start`'s `model` when non-empty (the default too, so the start runs the model the
  person saw even if the file changes meanwhile); empty is not sent.
- The row and the header read "<agent label> · <model label> via <provider>" when `Task.model` is non-empty;
  `""` reads "<agent label> · its own default model"; null (older daemon) shows as today. A model label is mapped
  only where certain (`claude-opus-5-5` → "Opus 5.5" and the same pattern for Claude's ids); any other id is shown
  as it comes.

### Tests (each guards a harm)

- Client against `MockDaemon`: each method's parameters and replies; each error to its type; `MethodNotFound` on
  each to `FeatureNotSupported`; a `Task` and a `Project` without the new fields read as null/empty.
- **A start without a sign-in**: with `NOT_SIGNED_IN`, `SIGNING_IN`, `VAULT_SHUT`, `CANNOT_SIGN_IN`, an unknown
  state, a refusal and a lost connection, `begin` yields nothing and the stand-in sees no `Start`.
- **A second sign-in**: with `SIGNING_IN`, and with `SignInRunning` from `AgentSignInStart`, the stand-in sees
  `AgentSignInWait` and no (further) `AgentSignInStart`; in the batch two rows of one agent make one sign-in.
- **The batch order**: one `AgentSignIns` per machine; the second agent's sign-in starts only after the first's
  `SIGNED_IN`; no `Start` before all are signed in.
- **A secret shown or logged**: the pasted code reaches only `AgentSignInCode`; it is in no operation output,
  message or exception text, and the field is empty after Send.
- **The wrong machine**: the form opened on machine A, the current machine switched to B; every sign-in call and the
  `Start` reach A's stand-in, none B's.
- **Cancel**: closing the form during a session sends `AgentSignInCancel(session)` and no `Start`.
- **An older daemon**: without the methods the start goes on as today (`CanStart`, the terminal login), without
  the fields the names are today's and no model line shows, and `Start` carries no `model` unless one was typed.

### What of the wire is guessed

- Whether every `AgentSignInStart` reply carries `session`, or only the first; and whether `url` may change between
  replies (taken: every reply may carry them, the latest wins).
- Whether a dropped `AgentSignInStart` stream cancels the session on the daemon (taken: no; the window calls
  `AgentSignInCancel` itself).
- What `AgentSignInWait` answers when nothing is running (taken: one final reply with the current state).
- What `detail` on a step is for (taken: words for the person, shown verbatim).
- Whether `AgentSignIns` keys by the `Agents` name (taken: yes) and whether it can answer for an agent not
  installed (taken: `NoSuchAgent`).
- A model's label: the wire gives only the id. Mapping it here is deriving what the daemon could say; a `label` on
  `ProviderModel` and on `Task` would be better, asked of Porelo.
- Which refusal `Start` gives when the sign-in went missing in a race (taken: a `CanStart`-like credential outcome).

### Open questions before building

- **A pasted code in a form here.** This repository's rule says the interface takes no secret into a form of its
  own and a sign-in code is typed into a terminal on its machine or the provider's own login. `WAITING_FOR_CODE`
  with `AgentSignInCode` is such a form. Either the operator's decision allows it for this flow (and the rule
  gets that exception), or the paste-code flow goes to a terminal on the machine and only the link flow is in the
  window.
- The forge token handed over "when the machine asks" is in no wire named yet; not built here.
