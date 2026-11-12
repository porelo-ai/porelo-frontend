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

- **Where a host's forge keeps a repository.** `HostPullRequest` names its repository by its name in the
  project's file, and nothing names the path of the host forge's copy of it. The window builds a pull request's
  address from the project's name and the last part of the repository's address, as the host names its copy;
  where the machine reports no address for the repository, the pull request is shown and cannot be opened.
- **Planning details and issue state changes.** The interface uses stand-in `GetStory(project, story)`,
  `ListStoryIssues(project, story)` and `GetIssue(project, issue)` reads for story text, issue acceptance
  criteria, last reader findings and sub-agents. Story and issue destinations share one pending batch and
  one Save. The stand-in `MoveStories(project, moves, revision)` accepts both `(story, to)` and `(issue, to)`
  entries atomically and returns `moved`, the new revision, and the complete workflow, story list and issue
  states. Story moves apply before explicit issue destinations. A stale revision returns
  `PlanningChanged(detail)` or `StaleRevision(revision)`; refused issue moves return
  `MoveNotAllowed(item, from, to, reason)`, `StateNotAllowed(item, from, to, reason)` or
  `EnteredOnlyByWork(item, to)`. The interface keeps still-applicable drafts after rereading stale planning
  and displays a refusal beside its named item. These stand-ins must be served before the flow works
  against a real machine.

- **The task name a start made.** `Start` answers the container on its final reply, not the task's name within the
  project; the window reads that name from `List` by the container, and refuses to answer a start whose container
  the list does not show.

- **A pushed commit's whole message** (a `message` on `PendingPush` and `ReviewCommit`, agreed for `Tasks1`, not
  served yet). The window reads it already: until it is served the trailer check cannot be made, since a
  `Co-Authored-By` outside git's trailer block is in no trailer line; the review shows no message body.

- **A task's names and model, and the model a start runs on per provider** (built in `Tasks1`, not served by a
  released Porelo yet). `Task` gains `model` (`""` for the agent's own default), `modelLabel`, `modelFrom` (`start`,
  `repository`, `project` or `agent`), `short`, `named` (the name the start was given, `""` when none) and `display`
  (what a client shows: named, else short, else the container name); `ProviderModels(project, repository?)` answers
  `ProviderModel(provider, model, label, from)` per provider. The interface reads them already: absent, a task's
  model and names read as not reported (never as the agent's own default), its name is shown as before, and the
  start form fills no model and says the machine takes the provider's default. Absent `model` on `Start` means the
  provider's default, so a task that ran its agent's own default (`""`) cannot be continued on that same own
  default while its provider has one: the wire has no way to ask for it.

- **An agent's sign-in as the machine's own login** (built in `Tasks1`, not served by a released Porelo yet).
  `AgentSignIns()` answers `AgentSignIn(agent, state, running?)` for every installed agent, state `SIGNED_IN`,
  `NOT_SIGNED_IN`, `VAULT_LOCKED` or `CANNOT_SAY`; `AgentSignInStart(agent, force?, remote?)` answers `(container,
  started, attach)`, starting the login or answering the one that runs, refused with `SignInRefused(agent, reason,
  detail)`; `AgentSignInWait(agent)` answers once `(stored, reason)` when the sign-in ends, at most 30 minutes later.
  The login is no task. Until served, every start goes as before: `CanStart`'s missing credential and the agent's
  own login in a terminal. The contract has no way to end a sign-in from the window; it ends in its terminal or by
  itself. `Start` names no refusal for a sign-in gone missing meanwhile; the window asks `AgentSignIns` after a
  failed start.

- **A repository's carry, central state and work on its machine** (built in Porelo, not served yet). `Repository`
  gains `carriedHere`, `tasks`, `running`, `ahead` with `aheadMeasured`, and `central` with `centralWhy`. The
  interface reads them already: a project's page opened from a machine says each repository's carry, central state
  and work from them, for a person who is no Machine Admin too; a repository not carried is not offered a start. Until
  served, those rows say what they said before, the carry and central state from the host's `org status` where a
  Machine Admin reads it. Giving a machine back still asks the host's `org status` alone.

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
  each agent declare waiting where it can; until then a quiet task is shown as a guess. An attached agent that
  declares its rest is no guess: the machine answers `AT_REST` or `WORKING` from its screen.

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
