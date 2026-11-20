---
name: frontend-client
description: porelo-frontend: the daemon contract and the client. Use when changing calls to the daemon.
---

# frontend-client

### The contract

- **Everything reaches a daemon through `org.fuin.porelo.Tasks1` over its socket; nothing parses the
  `porelo` CLI and no code is shared with the backend.** `ssh` (transport), `porelo task attach` in a
  pty (a session the contract cannot carry), a command the machine itself names, and `notify-send`
  (the desktop) are not breaches. Nothing reads or writes a backend's files.
- **No design here needs a token, a session or a login screen**; one that seems to is said in the
  channel rather than built.
- **The contract is served, never copied**: `dart tool/contract.dart <socket>` prints it from a
  running daemon.
- **A requirement is checked against the IDL parameter by parameter and field by field**, never
  against a method's name or a field named in prose. `doc/Contract-Gaps.md` is read before a
  requirement is picked up; what the daemon lacks goes there and is raised as a requirement in
  `porelo`, never designed around, and comes off the page once it has landed.
- **Take the highest `org.fuin.porelo.TasksN` `GetInfo` offers, turn `MethodNotFound` into
  `FeatureNotSupported` for that feature alone, ignore unknown fields, and render an unknown enum
  value rather than throwing** (`Outcome` is no Dart enum); a feature is never gated on the build
  version.
- **One call at a time per connection.** A stream ends only on a final reply, anything else is an
  error; a single call has a deadline (30 s, `GetInfo` 5 s), a stream never does.
- **Nothing is derived here that the daemon knows**: logs, credential keys, store commands,
  readiness, what `Start` would do, what a removal keeps. Render verbatim what only the daemon can
  compose; take counts, states and instants as parts and word them here.
- **Every project-scoped method takes the project's name, never a file path**, and a path is
  refused rather than answered as an empty list.
- **A change to the contract is agreed in the channel first**; within `Tasks1` it only grows, and a
  change that cannot is a `Tasks2` served beside it.

### The client

- **Only `lib/src/wire/` and `lib/src/client/` open a socket; the frame talks to `FleetBackend`.**
- **`VarlinkConnection.close()` destroys the socket**, because `Socket.close()` completes only when
  the peer closes; streams use an explicit subscription with `onCancel`, never `await for`, which
  cannot be interrupted while it waits.
- **A throw in a socket's `onData` never reaches `onError`**, so everything a peer can send wrong is
  caught there and reported as a lost connection; `mostBytesPerReply` bounds a reply with no end.
- **A forward this interface raises is `ssh -N` with `BatchMode=yes` and `ExitOnForwardFailure=yes`,
  believed only once a connection through it arrives**, and only what was raised here is ever taken
  down.
- **A command run on a machine over ssh goes through its login shell** (`inTheLoginShell`), or it
  meets the machine-wide `porelo` instead of the account's own.
- **Nothing forks out of Dart**: a pty child is made with `posix_spawn` and `POSIX_SPAWN_SETSID` and
  takes the terminal by opening it without `O_NOCTTY`.
- **The settings file is written beside itself and renamed over, and every stored field is checked
  rather than cast.**
