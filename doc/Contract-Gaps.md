# What the contract does not yet cover

What the interface needs that `org.fuin.porelo.Tasks1` has no method or field for yet. Once nothing
is left, the page goes.

A convincing screen with no method behind it is the most expensive kind of wasted work, because
it looks finished.

## The rule that makes these real gaps

- **The interface never parses the `porelo` CLI.** One that did would be a second implementation of
  every refusal the product makes, and those refusals are the product.
- **The interface never reads or writes the backend's files.** Over a forwarded socket there is no
  filesystem on that machine at all, so the API is the only way in.

Both rules, and why running `ssh` is not a breach of the first, are in [AGENTS.md](https://github.com/porelo-ai/porelo-frontend/blob/main/AGENTS.md). A
gap here is a backend method that has to be added, not a workaround waiting to be found.

## Not on the wire yet

- **A pushed commit's whole message** (a `message` on `PendingPush` and `ReviewCommit` is planned). The review
  shows each commit's first line and its trailer lines as the machine reports them, never the body between.

- **A task's names and model, and the default model per provider** (agreed for `Tasks1`, not served yet). `Task`
  gains `model` (what it was started with, `""` for the agent's own default), `modelLabel` (the provider's name for
  it), `display` (the room's name, `Agent Pi`), `short` (the name given at its start, else the one the machine made)
  and `named`; `Project.defaultModels` and `Repository.defaultModels` list `ProviderModel(provider, model, label,
  from)`, a repository's already merged over its project's. The interface reads them already: absent, a task's
  model and names read as not reported (never as the agent's own default), and its name is shown as before; the
  start form fills no default and says the machine takes the provider's default. Absent `model` on `Start` means
  the provider's default, so a task that ran its agent's own default (`""`) cannot be continued on that same own
  default while its provider has one: the wire has no way to ask for it.

- **An agent's sign-in as the machine's own login task** (agreed for `Tasks1`, not served yet).
  `AgentSignIns(agents?)` answers `AgentSignIn(agent, provider, state, since?, signingInSince?, loginTask?)`, state
  `SIGNED_IN`, `NOT_SIGNED_IN`, `SIGNING_IN`, `VAULT_SHUT` or `CANNOT_SIGN_IN`; `AgentSignInStart(agent)` answers
  `(task, started)`, starting the login task or naming the one that runs; `AgentSignInWait(agent)` streams `(state,
  detail?)` until `SIGNED_IN` or `NOT_SIGNED_IN`; refusals `CannotSignIn(agent, reason)`, `NoSuchAgent(agent)`,
  `VaultShut()`. `Task` gains `kind` (`LOGIN` for a login task). Ending a sign-in is stopping its login task. Until
  served, every start goes as before: `CanStart`'s missing credential and the agent's own login in a terminal.
  `Start` names no refusal for a sign-in gone missing meanwhile; the window asks `AgentSignIns` after a failed start.

- **Where a forwarded gate commit is retained.** `Approve` returns the incoming push name in `forwarded`, the
  destination `branch` and an optional `pullRequest`; it returns neither the forwarded commit nor its retained ref
  under `refs/porelo/forwarded/`. The interface reports the confirmed branch and cannot name that ref.

- **A repository's own settings in Default** (decided in Porelo, being built). `CanStart` answers
  `SETTINGS_NOT_ALLOWED` with `settingsToAllow` and `settingsHash`, or `SETTINGS_UNSIGNED` with `file` and
  `commit`; `AllowSettings(repository, hash)` answers `ALLOWED` or `CHANGED`; `FirstStart` names the file it
  writes in `fileName`, and `FirstStart` and `ConfirmFirstStart` take a repository in Default by its name where no
  checkout is here. The interface reads them already, and against a machine without them starts as before;
  `ImageSettings` and `Egress` list what a repository removed in `removed` (`key`, `by`), read already too.

- **Whether an agent is waiting on a person for its own question.** `WAITING` covers clearance
  questions only. The backend will observe working and quiet from outside for every agent, and let
  each agent declare waiting where it can; until then a quiet task is shown as a guess.

- **Removing a project the machine lists but does not know** (decided in Porelo, not built).
  `RemoveProject` with `dryRun` answers `NoSuchProject` for it, so *Remove this project* has nothing to
  show and nothing is removed from here; a blind `force` is not offered, because what it destroys
  includes pushes nobody reviewed. Porelo's change makes the preview answer `PREVIEWED` with `removes`,
  `keeps` and `unreviewed`, and the refusals any other project gets.

- **Where content Porelo delivered into a task came from.** The ranked review shows what a push
  changes in the machine's order, and would show the origin of what reached the task beside it;
  `Review` does not carry it yet.

- **Matrix in `porelo doctor`.** Whether a machine can carry messages, the transport and its
  homeserver answering, is shown for a project; the machine's own readiness does not include it.

- **A central homeserver shared by several machines**, which `porelo-message-matrix` plans. Until it is
  there, a machine's `Project.messages` says it is not admitted, with its address and the room, and
  a person invites each machine's account from a client of their own.

- **A homeserver's registration token on a host.** `project show` answers `matrix_registration_entry`; the interface
  does not yet read it or put that entry on `porelo-host-stop --stdin`.

## On the wire, not used here yet

- **`WatchProjects`**, a push for what `Projects` answers. The project row still asks again after
  anything that would change it; moving it onto the push makes its counts arrive rather than age.

## What becomes of a gap

A gap is closed by a backend method, raised as a requirement in the `porelo` repository: adding one
is additive and costs nothing under the compatibility promise. A local workaround would not
survive the first remote backend. What has landed is taken off this page.
