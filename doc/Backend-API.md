# The backend API

Everything this interface does, it does by calling Porelo's daemon, `porelod`, over one unix
socket. There is no HTTP, no port and no client library — the whole protocol is JSON objects
separated by NUL bytes, and Dart speaks it out of the box.

## The contract

The interface is `org.fuin.porelo.Tasks1`, defined in
[varlink](https://varlink.org/Interface-Definition) IDL. The definition lives in the backend
repository under `wire/src/main/resources/varlink/org.fuin.porelo.Tasks1/`, written in parts that
the daemon serves as one interface, and a build
there fails if a method is registered without appearing in it, or appears in it without being
registered, or reads a parameter it does not describe.

**No copy of it is kept in this repository**: a running daemon serves its own contract:

```
varlinkctl introspect $XDG_RUNTIME_DIR/porelo/porelod.sock org.fuin.porelo.Tasks1
```

or, without `varlinkctl`, `dart tool/contract.dart` in this repository, which prints the same
thing and works against a forwarded socket too. A copy checked in here would be a second source
of truth that nothing keeps honest.

## A project's source, address and removal

No method says where a project comes from: `porelo project list --json` answers each project's `source`
(`organization`, `local` or `built-in`), `role`, `locked`, `host` and `opened`, and `porelo project show
PROJECT --json` its `address`. Every read fetches, so *Refresh* simply reads again; a host's effect is
`org refresh`, on the host's page. These answers are kept in `Organization`, read only when a person's
view needs one, one at a time, and for five minutes or until *Refresh*. A project with no readable
address matches no forge, and says so.

`RemoveProject(name, dryRun?, force?)` answers a `Deletion`. It is offered only for a project whose `source`
is `local`, and not while the source cannot be read or the answer is `stale`; the daemon refuses a project
of the organization and `default` all the same. A daemon without it is `FeatureNotSupported`, for that
feature alone.

## Connecting

Locally, the socket is at `$XDG_RUNTIME_DIR/porelo/porelod.sock` — normally
`/run/user/<uid>/porelo/porelod.sock`. It is owner-only, so the filesystem is the access control;
there is nothing to authenticate against.

Remotely, forward it:

```
ssh -L /tmp/porelod-remote.sock:/run/user/1001/porelo/porelod.sock user@host -N
```

and open `/tmp/porelod-remote.sock` instead. **That is the entire difference between a local and
a remote Porelo** — one string, and the interface has one transport for both. Streaming works through the forward
unchanged; measured, an event raised on the far machine arrived 0.4 s later.

`ssh` creates the local endpoint owner-only, so the forwarded socket is no more exposed than the
original.

## Speaking it

```dart
import 'dart:convert';
import 'dart:io';

final socket = await Socket.connect(
    InternetAddress(path, type: InternetAddressType.unix), 0);

socket.add(utf8.encode(jsonEncode({
  'method': 'org.fuin.porelo.Tasks1.List',
  'parameters': <String, dynamic>{},
})));
socket.add([0]);          // NUL terminates the call
```

Replies come back the same way: one JSON object per NUL. Three things to know.

- **Streaming.** Add `'more': true` to the call. Every reply but the last then carries
  `"continues": true`. `Watch`, `Tail`, `Start` and `Prompts` stream; `Prompts` *only* streams
  and refuses a call without `more`.
- **Errors** arrive as an object with `error` (the fully-qualified name) and `parameters`,
  instead of `parameters` alone. They are answers, not faults — `HOLDS_WORK` from `Stop` is the
  gate working.
- **One call at a time per connection.** The framing has no request ids. Open a connection per
  stream; that is what it is for, and it costs nothing.

## Staying compatible with older backends

A fleet is not upgraded at once, so this interface will meet daemons older than itself. The
contract commits to three things, and the IDL states them in full at the top of the file:

1. **The `1` in `Tasks1` is the promise.** Within it the interface only grows — new methods, new
   optional parameters, new reply fields. Nothing is removed, renamed, retyped, or given a new
   meaning. A change that cannot be made that way becomes `Tasks2`, served *beside* `Tasks1` for
   at least one release. So a client calls `org.varlink.service.GetInfo`, reads its `interfaces`
   list, and uses the highest one it understands, never comparing version numbers to decide it.

2. **Degrade per feature, not per connection.** A method an older daemon lacks answers
   `org.varlink.service.MethodNotFound`; a client turns off that one feature and keeps the rest. An
   optional parameter an older daemon does not know is ignored, and it behaves as its documented
   default says.

3. **Unknown values are not fatal.** A client ignores reply fields it does not recognize, and
   renders an unrecognized enum value rather than throwing on it. `Outcome` in particular will gain entries,
   and adding one is explicitly *not* a breaking change — so a client that cannot survive one
   will break on a routine release. This is the rule most likely to be broken by a generated
   Dart enum with no fallback case.

`GetInfo` also reports the daemon's build version. The interface shows it, for bug reports, and
gates no feature on it.

## What is there

The IDL carries the detail, a comment per method and per field. The shape of it:

| | |
|---|---|
| **What exists** | `List`, `Watch` (streams), `Projects`, `WatchProjects` (streams), `Agents`, `Credentials` |
| **A start a host certifies** | `Start` with `certify: true`, where declared, gives one `certify: {start, key, principal, key_id, valid_before, certifiers}` in its stream; the window checks it, has the local agent sign and answers `Certify(start, certificate?, refused?)`. A wait ends at five minutes or when the stream closes |
| **A carried project** | A row of `Projects` with `carried: true` and an empty `file`: the host carries it and this person has not taken it here. `TakeProject` takes it, once, at a person's act, and answers `{file}` or `{reason, words}`; a list never takes |
| **A repository on its machine** | A `Repository` of `Projects` says `carriedHere` (whether this machine, a host of the project, carries it; absent on a machine that is no host of it), `tasks` and `running` (its work, and how much is up), `central` with `centralWhy` (how the host forge's copy stands against central, as the host last said; new values may appear), and `ahead` with `aheadMeasured` (the commits for central, as last answered). The window takes each where it is said, on the project's page opened from a machine, its rows' start and the repositories *New work* offers; where one is absent it says what it said before or *not reported*, never 0 and never up to date |
| **Running tasks** | `Start` (creates or brings back; streams the build), `Stop` (keeps it), `Remove`, `Tail` (follows a log) |
| **Builds of a push** | `Task.builds`, `buildReader`, `buildProblem` (no method: `Watch` carries them) |
| **Files handed in** | `HandIn` (in parts), `TakeBack`, `HandIns` (the record, also after the task is gone) |
| **The gate** | `Pending`, `Review`, `Approve`, `Reject`; `CredentialTryPush` tries a forward with one ssh key alone |
| **Clearance** | `Prompts` (streams, and only streams), `Decide` |
| **A host forge's pull requests** | `WatchPullRequests(project)` (streams), `PullRequests(project)`; refused with `MissingHostForgeToken(credential, storeCommand)` or `HostPullRequestsRefused(reason, message)` |

Worth knowing before designing around them:

- **`Approve` refused for its key is `PushRefused`**, before the forge is reached where no single key is
  declared for the address (`NO_CREDENTIAL`) or the declared one cannot be used (`KEY_UNAVAILABLE`), and
  after it otherwise (`PUSH_REFUSED`). It carries the key used by fingerprint, `forge` `DEPLOY_KEY` only
  where the forge said so, and the next command as arguments; never the forge's own line. The window
  lists `SshKeys` (an agent's with `found: AGENT`), tries one with `CredentialTryPush`, which writes
  nothing, and keeps one with `CredentialDeclare` (`SSH_KEY`, the refused address, `AGENT` by
  fingerprint or `FILE` by path) before it calls `Approve` again.
- **`Review` counts each file twice where the machine can**: `added` and `removed` as git counts
  them, and `addedIgnoringLineEndings` and `removedIgnoringLineEndings` without what changed at line
  ends (git's `--ignore-space-at-eol`, which also leaves out spaces there). Absent is not zero. Its
  `ignoreLineEndings` answers the diff without them, and is sent only to a machine whose `Review`
  names it, since an older one refuses a parameter it does not know.
- **Who made a waiting push is shown as the machine reports it, and its trailer is checked here.**
  `Review`'s `commits` lists each commit newest first with `author`, `committer` (`name <email>`) and
  `trailers` and its whole `message`; where it is absent, `PendingPush`'s own `author`, `committer`,
  `trailers` and `message` name the head commit. Exactly one `Assisted-by` and no `Co-Authored-By`
  (keys read without regard to case, as git does) passes; a `Co-Authored-By` line anywhere in the
  message counts too, since one outside git's trailer block is in no trailer line. Anything else says
  what is wrong. An absent field, an empty message (one the machine could not match to its commit),
  or a list holding anything but text, is not reported, and the check is then one that cannot be
  made, never one that passed.
- **A host forge's open pull requests are watched for each project the machine carries a repository of**
  (`carriedHere`), and each is a row of *Needs you* asking for its approval and merge on that forge. A row
  closes only when the watch lists it in `ended`; a watch that ends with an error closes none, its rows read as
  possibly out of date, and it is asked again. Its makers are shown through the trailer check above; without
  the whole message that check is one that cannot be made. The window never asks the forge itself: it opens
  the host card's forge forward at the project's name, the last part of the repository's address (as the host
  names its copy) and the positive number. A missing token is said with the store command to copy and run on
  the machine; a refusal in words for its reason, with the machine's message.
- **A task whose agent said its work is done** has activity `DONE` and state `done`, whether its container
  is up or stopped. It is shown as done, never as running, and no count of running work here counts it; it
  needs a person only for what else it holds, such as work at the gate.
- **`Stop` refuses.** A task holding commits that never reached the gate comes back as
  `HOLDS_WORK` and is left exactly as it was. That refusal is a feature and needs a real place in
  the interface, not an error toast.
- **`Stopped`'s `surviving` is read as a count or as a list of names**, and an absent or malformed
  value reads as not reported, never as none.
- **`HandIn` goes in parts, each a call of its own.** A request may be at most 4 MiB, the JSON
  around the base64 included, and a single call has a deadline, so a file goes in parts of 1 MiB.
  Every part repeats the name, size and SHA-256; a part at the wrong offset is refused as
  `PartOutOfOrder`, which carries where the machine is, so a cut connection costs one part and the
  hand-in goes on from there. The file reaches the task only once it is whole and its hash matches,
  so nothing is shown as handed in before the answer carries `file`. The task's `handInLimit` is
  read first, and a larger file is refused here before a byte of it is read. A machine without
  hand-in leaves `files`, `handInLimit` and `run` absent, which is drawn as absent, never as empty;
  `by` is `"porelo"` for what Porelo hands in itself.
- **A task's output age and inbox count come with the task.** `Task.lastWrote` is the ISO-8601
  instant its log was last written, or `""` without a write; changing it alone does not trigger
  `Watch`. `Task.inboxWaiting` counts messages waiting in the task's inbox for every listed task,
  including running, ended and stopped work. Both fields are optional: absent means not reported,
  so no age or inbox count is guessed. The last output line comes from `Tail(last: 1)`. An
  unattended run is never woken by a message; quiet is described as silence.
- **A task's names and model come with the task.** A task is shown by its `label` where somebody set one, else by
  `display` (what the machine says a client shows), else by `name`; `name`, the container, is what every call takes
  and is shown only in its details. `model` is what its start settled, `""` for the agent's own default;
  `modelLabel` is shown as it comes, else the id, with `modelFrom` beside it. All are optional: absent means not
  reported. The start form asks `ProviderModels(project, repository?)` of its own machine and fills its model with
  the entry whose provider is the one `CanStart` names (`""` from `agent` reads as the agent's own default); not
  served or failed, the field stays empty. `Start`'s `model` is sent only when the field holds one; *Continue*,
  *Restart* and *Recreate* send the task's own, and a start of an agent for each repository sends none.
- **An agent's sign-in is the machine's own login, which is no task.** Before a start, and once for every agent of a
  start of several, the window asks `AgentSignIns()`; every state but `SIGNED_IN` holds the start (`VAULT_LOCKED`
  and an unknown one too), and `CanStart` still has to clear. `CANNOT_SAY`, and a wait ended as `CANNOT_SAY` or
  `NO_PROVIDER`, leaves it to `CanStart`: answered ready, the start goes and no sign-in is offered; not answered, or
  holding, it holds. *Sign in* sends `AgentSignInStart(agent,
  remote?)`, `remote: true` for a machine this window reaches from another one, which starts the login or answers
  the one that runs (`started` false: never a second). Its `attach` is run on that machine in a terminal, as any
  command the machine names (over ssh in the login shell); the person follows the link and pastes the code there.
  `SignInRefused` is said with its `detail`; after `ALREADY_SIGNED_IN` the window offers `ImportCredential` first
  and `force: true` only on a second press. `AgentSignInWait(agent)` answers once, when the sign-in ended: **its own
  deadline is 31 minutes, past the machine's 30, not the 30 seconds of a single call, and it runs on a connection of
  its own**, closed when the wait is left (the form closed or opened again, the machine forgotten), which does not
  end the sign-in; a start or question still out when it is left opens no wait and no terminal on its late answer.
  The terminal only watches the login (`podman attach --sig-proxy=false`), so closing it ends nothing either, and
  while it is open *Sign in* opens no second one. Every `AgentSignInStart` answered is waited on by the container it
  names. Only `stored: true` reads as signed in. Against a machine without these methods a start goes as
  before.
- **A task's builds come with the task.** `buildReader` `""` means no forge follows its pushes and
  nothing is said; set, with `builds` empty and `buildProblem` `""`, it means nothing was pushed yet;
  `buildProblem` says why a named reader does not work. A `Build` lists its jobs only once the verdict
  is `failure` or final, and a job's `log` is the name of a file in the task, never its text. All
  three are absent from a machine older than builds, which is drawn as saying nothing.
- **A build's `runs` give the tile one line per workflow run**, each `name` with its `result` as the
  forge spells it (`queued` and `in_progress` while it is not finished; one not known here is shown as
  it comes and is no pass). The tile says passed only where the verdict is `success` and every run
  succeeded; a failed run is named whatever the verdict says; a verdict other than `success` is said
  as it is beside the runs listed so far; and `runs` empty beside `success` says no workflow ran.
  Where `runs` is absent (an older machine), the jobs are grouped by their `"<workflow> / <job>"` name
  instead.
- **`Prompts` has a deadline.** A task is *blocked* while a clearance prompt is unanswered and
  the watcher gives up after its own timeout. This is the one place where interface latency costs
  something real, which is why it is a stream and not a poll.
- **`ProjectMessages.waits` is the daemon's explanation of why messages wait.** `waitsOn`, after
  `waits`, is a string identifying the dependency: `"vault"` while the vault is locked, otherwise
  `""`. It is optional for older daemons. Unknown values are kept as text and show only `waits`,
  without guessing a recovery action from its sentence.
- **`ProjectMessages.vault` names the vault file the daemon checked.** It is a string set when
  `waitsOn` is `"vault"`, otherwise `""`. An older daemon can omit it; the interface then keeps the
  daemon's existing explanation without guessing a vault path.
- **`Project.lastUsed` is the latest task start or message event for that project on that machine.**
  It is an ISO-8601 string, or `""` when none exists. An omitted field from an older daemon means
  not reported, rather than never used. The interface words the elapsed time using its clock.
- **`WatchProjects` is slower than `Watch`, on purpose.** A project scan runs the container
  runtime and reads the gate's refs for every project, and what it answers changes on human
  timescales - a project created, a push arriving at the gate, an environment prepared. It sends
  the whole list on change and nothing in between; measured quiet for twelve seconds with nothing
  happening, and firing within the interval when a project appeared and again when it went. Unlike
  `Watch` there is no age to exclude: `behindMeasured` moving *is* a change, because the age drawn
  beside the number resets with it.
- **`Prompt` says when it runs out.** `deadline` is ISO-8601 and `""` when there is none - and
  `""` on a settled event too, because nothing is waiting on an answer that arrived. It is measured
  from when the question was asked rather than from `at`: `at` is when the connection was blocked,
  and a watcher that has fallen behind would otherwise send a deadline already past. An open
  question carries `deadline`, `at` and `prefix`.
  **The deadline belongs to the question, not to the packet:** a dropped connection is retried, so
  the same destination arrives again while one question is open - `at` moves with each event, the
  deadline does not. Measured against a real blocked connection: four events for one destination,
  one deadline, and `""` on the verdict that ended it.
- **A destination is announced as open at most once.** The watcher sees every retry of a dropped
  connection but does not publish a key it has already answered, so a settled question is never put
  back on screen.
- **`Prompts` streams the answer too.** A settled prompt arrives again with `verdict` set, and
  `"timeout"` is the only way a client learns one expired. Match it to the question by `task` and
  `key`; the other fields deliberately differ between the two events.
