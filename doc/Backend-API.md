# The backend API

Everything this interface does, it does by calling Porelo's daemon, `porelod`, over one unix
socket. There is no HTTP, no port and no client library — the whole protocol is JSON objects
separated by NUL bytes, and Dart speaks it out of the box.

## The contract

The interface is `org.fuin.porelo.Tasks1`, defined in
[varlink](https://varlink.org/Interface-Definition) IDL. The definition lives in the backend
repository under `daemon/src/main/resources/varlink/org.fuin.porelo.Tasks1/`, written in parts that
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
| **Running tasks** | `Start` (creates or brings back; streams the build), `Stop` (keeps it), `Remove`, `Tail` (follows a log) |
| **Builds of a push** | `Task.builds`, `buildReader`, `buildProblem` (no method: `Watch` carries them) |
| **Files handed in** | `HandIn` (in parts), `TakeBack`, `HandIns` (the record, also after the task is gone) |
| **The gate** | `Pending`, `Review`, `Approve`, `Reject` |
| **Clearance** | `Prompts` (streams, and only streams), `Decide` |

Worth knowing before designing around them:

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
- **A task's builds come with the task.** `buildReader` `""` means no forge follows its pushes and
  nothing is said; set, with `builds` empty and `buildProblem` `""`, it means nothing was pushed yet;
  `buildProblem` says why a named reader does not work. A `Build` lists its jobs only once the verdict
  is `failure` or final, and a job's `log` is the name of a file in the task, never its text. All
  three are absent from a machine older than builds, which is drawn as saying nothing.
- **`Prompts` has a deadline.** A task is *blocked* while a clearance prompt is unanswered and
  the watcher gives up after its own timeout. This is the one place where interface latency costs
  something real, which is why it is a stream and not a poll.
- **`ProjectMessages.waits` is the daemon's explanation of why messages wait.** `waitsOn`, after
  `waits`, is a string identifying the dependency: `"vault"` while the vault is locked, otherwise
  `""`. It is optional for older daemons. Unknown values are kept as text and show only `waits`,
  without guessing a recovery action from its sentence.
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
