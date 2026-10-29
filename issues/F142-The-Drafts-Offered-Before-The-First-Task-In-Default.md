# F142 — The Drafts Offered Before The First Task In Default

**Status:** Analyzed.
**Size:** M - two calls and a field in the client, one dialog awaited at the one place a start
begins, the mock and the fake taught them, a feature file.

**What must be true.** When a person starts the first task on a repository in `default` that has no
configuration yet, the interface shows the tools and rules the machine proposes from the repository's
files, as
the command line shows them, and passes the person's choice back; the default choice changes
nothing, a declined proposal is not asked again, and a machine that cannot propose starts the task as
today.

## Plan

- **The client** (`lib/src/client/porelo_client.dart`, `models.dart`): `DefaultRepository.proposal`
  read as a string (`UNASKED`, `ASKED`, `CONFIGURED`, another said as it comes, absent from an older
  machine); `proposeProject(project, repository)` as a `_callMore` stream like `prepare`, mapped to a
  `ProposalProgress` per plugin and a final `Proposal` (tools, rules, each
  `{key, value, file, line, origin, unknown, note}`, disagreements, the cost sentence, the
  `.porelo.yml` and `project.yml` texts, `storeCommand` and `storeStdin` per credential id as
  `CredentialDeclare` answers them, the machine's name), every field checked rather than cast; `takeProposal(project, repository, choice)` answering the
  `project.yml` text. Both on `FleetBackend` and `PoreloBackend`; `MethodNotFound` becomes
  `FeatureNotSupported` for this feature alone.
- **Where it is asked**: `_beginTheRun` in `lib/src/ui/shell.dart` is the one place every start goes
  through, `default_view`'s rows included. It becomes async: for `default`, it reads the chosen
  repository's `proposal` from `defaultRepositories()`, and only on `UNASKED` awaits the dialog
  before `operations.run`. `ASKED`, `CONFIGURED`, an absent field and `FeatureNotSupported` start at
  once, the last with one line saying the machine cannot propose.
- **The dialog**, a new `lib/src/ui/proposal_view.dart` beside `default_view.dart`: the stream's
  progress as it comes, then tools and rules apart, every value with its file and line, `CHECKOUT`
  marked with a warning, `YOURS` named as the machine's account, unknown values and disagreements
  listed, the cost sentence verbatim, the `.porelo.yml` text shown before the choice. Three buttons,
  *Start with the default image* the default (`NONE`), *Take the tools* (`TOOLS`) and *Take the tools
  and keep the project draft* (`TOOLS_AND_DRAFT`), the last saving the answered `project.yml` text
  into a folder picked with `pickWithTheDesktop`, as the command line writes it to a directory. Each
  credential id offers its `storeCommand` through `runInATerminal` where `storeStdin` is empty, as a
  check's missing value is stored today, and otherwise shows the command and what it reads on its
  standard input, as `connections_view.dart` does. Closing the dialog starts nothing and sends nothing.
- **Stand-ins**: `lib/src/mock/machine.dart` serves `ProposeProject` through `stream` and
  `TakeProposal` from what the test tells it; `FakeBackend` the same for the frame.
- **The test that goes red first**: in `test/features/work_without_a_project.feature`, *a first start
  in default shows the proposal before any task exists*, red while `_beginTheRun` runs at once.
- `doc/Backend-API.md` gains the two methods and the field.

## Acceptance

- A first start on an `UNASKED` repository shows the proposal before any task exists, and with the
  default choice the task starts with `TakeProposal(NONE)` sent and nothing written here; seen to
  fail first with the start not waiting.
- A value from the checkout is shown marked apart from one from the person's own files.
- A start on an `ASKED` or `CONFIGURED` repository asks nothing.
- A stream that ends without a final reply is said as cut short, and the task does not start.
- Against a daemon without `ProposeProject`, the start goes on and says why nothing was proposed.

## To be checked

- How long a proposal takes on a real repository, measured on the VM once the machine proposes them, to word the
  wait.
